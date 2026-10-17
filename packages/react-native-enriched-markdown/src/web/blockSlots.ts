import type { ASTNode, NodeType } from './types';
import type {
  MarkdownBlock,
  MarkdownImageOccurrence,
  MarkdownImagePlacement,
  MarkdownBlockPlacement,
} from '../types/MarkdownTextProps';
import { extractNodeText } from './utils';

export interface CollectedBlocks {
  blocks: MarkdownBlock[];
  images: MarkdownImageOccurrence[];
}

// Ids count earlier occurrences of the same base, in document order.
class IdCounter {
  private counts = new Map<string, number>();
  next(kind: string, url: string): string {
    const base = `${kind}:${fnv1a64Hex(url)}`;
    const count = this.counts.get(base) ?? 0;
    this.counts.set(base, count + 1);
    return `${base}:${count}`;
  }
}

/**
 * The web twin of `packages/core/cpp/parser/BlockSlots.cpp`: the same walk, the
 * same eligibility rule and the same id scheme (`<kind>:<fnv1a64 hex of url>:<n>`,
 * slots and image occurrences counted separately), so an app's renderer and
 * resolver see identical ids on every platform. The walk also stamps
 * `blockSlotId` on every eligible block (the C++ core stamps only the active
 * ones; on web the renderer result map decides) and `imageOccurrenceId` on
 * every image, which the renderers read.
 */
export function collectBlocks(root: ASTNode): CollectedBlocks {
  const slotIds = new IdCounter();
  const imageIds = new IdCounter();
  const result: CollectedBlocks = { blocks: [], images: [] };

  const recordImage = (
    image: ASTNode,
    placement: MarkdownImagePlacement
  ): void => {
    const url = image.attributes?.url ?? '';
    const id = imageIds.next('image', url);
    result.images.push({
      id,
      url,
      altText: extractNodeText(image).trim(),
      title: image.attributes?.title ?? '',
      placement,
    });
    image.attributes = { ...image.attributes, imageOccurrenceId: id };
  };

  const visit = (
    node: ASTNode,
    parentType: NodeType,
    ancestors: { inLink: boolean; inTable: boolean; inList: boolean }
  ): void => {
    // The hosts lay lists out as text, so nothing inside one can be replaced.
    const inSlotContainer = isSlotContainer(parentType) && !ancestors.inList;

    if (node.type === 'Video') {
      if (inSlotContainer) {
        const url = node.attributes?.url ?? '';
        const id = slotIds.next('video', url);
        result.blocks.push({
          kind: 'video',
          id,
          url,
          placement: slotPlacement(parentType),
        });
        node.attributes = { ...node.attributes, blockSlotId: id };
      }
      return;
    }

    if (node.type === 'Image') {
      recordImage(
        node,
        ancestors.inLink
          ? 'link'
          : ancestors.inTable
            ? 'table'
            : ancestors.inList
              ? 'list'
              : 'inline'
      );
      return;
    }

    if (inSlotContainer && isStandaloneLinkParagraph(node)) {
      const link = node.children![0]!;
      const url = link.attributes?.url ?? '';
      const id = slotIds.next('link', url);
      result.blocks.push({
        kind: 'link',
        id,
        url,
        label: extractNodeText(link).trim(),
        title: link.attributes?.title ?? '',
        placement: slotPlacement(parentType),
      });
      node.attributes = { ...node.attributes, blockSlotId: id };
      // The link's content (a linked image, say) still walks below for image occurrences.
    }

    if (inSlotContainer && isStandaloneImageParagraph(node)) {
      const image = node.children![0]!;
      const url = image.attributes?.url ?? '';
      const id = slotIds.next('image', url);
      const placement = slotPlacement(parentType);
      result.blocks.push({
        kind: 'image',
        id,
        url,
        altText: extractNodeText(image).trim(),
        title: image.attributes?.title ?? '',
        placement,
      });
      node.attributes = { ...node.attributes, blockSlotId: id };
      recordImage(image, placement);
      return;
    }

    const childAncestors = {
      inLink: ancestors.inLink || node.type === 'Link',
      inTable: ancestors.inTable || node.type === 'Table',
      inList: ancestors.inList || node.type === 'ListItem',
    };
    node.children?.forEach((child) => visit(child, node.type, childAncestors));
  };

  root.children?.forEach((child) =>
    visit(child, root.type, { inLink: false, inTable: false, inList: false })
  );
  return result;
}

function isSlotContainer(type: NodeType): boolean {
  return type === 'Document' || type === 'Blockquote' || type === 'Admonition';
}

function slotPlacement(container: NodeType): MarkdownBlockPlacement {
  if (container === 'Blockquote') return 'blockquote';
  if (container === 'Admonition') return 'admonition';
  return 'root';
}

function isStandaloneLinkParagraph(node: ASTNode): boolean {
  return (
    node.type === 'Paragraph' &&
    node.children?.length === 1 &&
    node.children[0]?.type === 'Link'
  );
}

function isStandaloneImageParagraph(node: ASTNode): boolean {
  return (
    node.type === 'Paragraph' &&
    node.children?.length === 1 &&
    node.children[0]?.type === 'Image'
  );
}

/** FNV-1a 64 over the UTF-8 bytes, as 16 lowercase hex digits. */
export function fnv1a64Hex(text: string): string {
  let hash = 0xcbf29ce484222325n;
  const prime = 0x100000001b3n;
  for (const byte of new TextEncoder().encode(text)) {
    hash ^= BigInt(byte);
    hash = (hash * prime) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, '0');
}
