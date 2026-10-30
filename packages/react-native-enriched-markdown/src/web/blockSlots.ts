import type { ASTNode, NodeType } from './types';
import type {
  MarkdownBlock,
  MarkdownImageOccurrence,
  MarkdownImagePlacement,
  MarkdownBlockPlacement,
} from '../types/markdownBlocks';
import { extractNodeText } from './utils';

export interface CollectedBlocks {
  blocks: MarkdownBlock[];
  images: MarkdownImageOccurrence[];
}

// Ids count earlier entries with the same base, in document order.
class IdCounter {
  private counts = new Map<string, number>();
  next(prefix: string, identity: string): string {
    const base = `${prefix}:${fnv1a64Hex(identity)}`;
    const count = this.counts.get(base) ?? 0;
    this.counts.set(base, count + 1);
    return `${base}:${count}`;
  }
}

// The whitespace the core trims from alt text and labels; String#trim also
// strips Unicode spaces, which would change the id.
function trimAscii(text: string): string {
  return text.replace(/^[ \t\r\n]+|[ \t\r\n]+$/g, '');
}

/** What an id hashes: the URL, text and title joined by U+001F, as in the core. */
export function blockIdentity(url: string, text = '', title = ''): string {
  return `${url}\u001f${text}\u001f${title}`;
}

/**
 * The web twin of `packages/core/cpp/parser/BlockSlots.cpp`: the same walk, the
 * same eligibility rule and the same ids (`<kind>:<hash>:<n>` for a block,
 * `img:<hash>:<n>` for an image occurrence, the hash over URL, text and title),
 * so an app's renderer and resolver see identical ids on every platform. The
 * walk also stamps `blockSlotId` on every eligible block (the C++ core marks
 * only the active ones; on web the renderer result map decides) and
 * `imageOccurrenceId` on every image, which the renderers read.
 */
export function collectBlocks(root: ASTNode): CollectedBlocks {
  const slotIds = new IdCounter();
  const imageIds = new IdCounter();
  const result: CollectedBlocks = { blocks: [], images: [] };

  const recordImage = (
    image: ASTNode,
    placement: MarkdownImagePlacement
  ): string => {
    const url = image.attributes?.url ?? '';
    const altText = trimAscii(extractNodeText(image));
    const title = image.attributes?.title ?? '';
    const id = imageIds.next('img', blockIdentity(url, altText, title));
    result.images.push({ id, url, altText, title, placement });
    image.attributes = { ...image.attributes, imageOccurrenceId: id };
    return id;
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
        const id = slotIds.next('video', blockIdentity(url));
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
      const label = trimAscii(extractNodeText(link));
      const title = link.attributes?.title ?? '';
      const id = slotIds.next('link', blockIdentity(url, label, title));
      result.blocks.push({
        kind: 'link',
        id,
        url,
        label,
        title,
        placement: slotPlacement(parentType),
      });
      node.attributes = { ...node.attributes, blockSlotId: id };
      // The link's content (a linked image, say) still walks below for image occurrences.
    }

    if (inSlotContainer && isStandaloneImageParagraph(node)) {
      const image = node.children![0]!;
      const url = image.attributes?.url ?? '';
      const altText = trimAscii(extractNodeText(image));
      const title = image.attributes?.title ?? '';
      const id = slotIds.next('image', blockIdentity(url, altText, title));
      const placement = slotPlacement(parentType);
      const occurrenceId = recordImage(image, placement);
      result.blocks.push({
        kind: 'image',
        id,
        url,
        altText,
        title,
        placement,
        occurrenceId,
      });
      node.attributes = { ...node.attributes, blockSlotId: id };
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

const encoder = new TextEncoder();
const hashes = new Map<string, string>();
const MAX_CACHED_HASHES = 1024;

/* eslint-disable no-bitwise -- a hash function */
/**
 * FNV-1a 64 over the UTF-8 bytes, as 16 lowercase hex digits. Four 16-bit
 * limbs instead of BigInt: the prime is 2^40 + 0x1b3, so each round is a few
 * small multiplications. Memoised, since a streaming document hashes the same
 * blocks on every tick.
 */
export function fnv1a64Hex(text: string): string {
  const cached = hashes.get(text);
  if (cached !== undefined) return cached;
  let h0 = 0x2325;
  let h1 = 0x8422;
  let h2 = 0x9ce4;
  let h3 = 0xcbf2;
  for (const byte of encoder.encode(text)) {
    h0 ^= byte;
    const t0 = h0 * 0x1b3;
    const t1 = h1 * 0x1b3 + (t0 >>> 16);
    const t2 = h2 * 0x1b3 + h0 * 0x100 + (t1 >>> 16);
    const t3 = h3 * 0x1b3 + h1 * 0x100 + (t2 >>> 16);
    h0 = t0 & 0xffff;
    h1 = t1 & 0xffff;
    h2 = t2 & 0xffff;
    h3 = t3 & 0xffff;
  }
  const hex = [h3, h2, h1, h0]
    .map((limb) => limb.toString(16).padStart(4, '0'))
    .join('');
  if (hashes.size >= MAX_CACHED_HASHES) hashes.clear();
  hashes.set(text, hex);
  return hex;
}
/* eslint-enable no-bitwise */
