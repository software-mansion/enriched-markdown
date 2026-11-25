import {
  createContext,
  useContext,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type RefObject,
} from 'react';
import { extractNodeText } from '../utils';
import type { RendererProps, RendererMap, ASTNode, NodeType } from '../types';
import {
  ENRM_LIST_ATTR,
  ENRM_LIST_MARKER_ATTR,
  ENRM_TASK_CHECKBOX_CLASS,
  injectGlobalStyles,
} from '../globalStyles';
import {
  bulletStyle,
  checkedTaskTextStyle,
  leadingCodeBlockMarkerTop,
  listGap,
  listItemStyle,
  listMarkerStyle,
  orderedMarkerStyle,
  ORDERED_MARKER_NUMBER_STYLE,
  ORDERED_MARKER_SIZER_STYLE,
  TASK_CHECKBOX_INERT_STYLE,
} from '../styles';

const NESTED_LIST_TYPES: Set<NodeType> = new Set([
  'UnorderedList',
  'OrderedList',
]);

const NUMBER_COLUMN_EM = 1.5;

const useIsomorphicLayoutEffect =
  typeof window === 'undefined' ? useEffect : useLayoutEffect;

interface ListInfo {
  depth: number;
  ordered: boolean;
  start: number;
  column: number;
  baseColumn: number;
}

const ListContext = createContext<ListInfo | null>(null);

const LIST_ATTRS = { [ENRM_LIST_ATTR]: true };

const NestedListOffsetContext = createContext(0);

function ListRenderer({
  node,
  style,
  styles,
  parentType,
  capabilities,
  renderChildren,
  listTag: ListTag,
}: RendererProps & { listTag: 'ul' | 'ol' }) {
  const parent = useContext(ListContext);
  const nestedOffset = useContext(NestedListOffsetContext);
  const isNested = parentType === 'ListItem';
  const ordered = ListTag === 'ol';
  const start = Math.max(0, Number(node.attributes?.start ?? 1) || 0);
  const listRef = useRef<HTMLOListElement & HTMLUListElement>(null);
  const numbers = useNumberColumn(
    listRef,
    ordered,
    node.children?.length ?? 0,
    style.list
  );

  const { markerMinWidth, bulletSize, fontSize } = style.list;
  const baseColumn = Math.max(
    markerMinWidth,
    ordered ? (numbers?.base ?? fontSize * NUMBER_COLUMN_EM) : bulletSize / 2,
    0
  );
  const info: ListInfo = {
    depth: parent ? parent.depth + 1 : 0,
    ordered,
    start,
    column: Math.max(baseColumn, numbers?.widest ?? 0),
    baseColumn,
  };
  return (
    <ListContext.Provider value={info}>
      <ListTag
        ref={listRef}
        {...LIST_ATTRS}
        start={ordered && start !== 1 ? start : undefined}
        style={
          isNested
            ? { ...styles.listNested, marginInlineStart: nestedOffset }
            : styles.list
        }
        dir={capabilities.blockDir}
      >
        {renderChildren(node)}
      </ListTag>
    </ListContext.Provider>
  );
}

function useNumberColumn(
  listRef: RefObject<HTMLElement | null>,
  ordered: boolean,
  itemCount: number,
  listStyle: object
): { widest: number; base: number } | null {
  const [size, setSize] = useState<{ widest: number; base: number } | null>(
    null
  );
  useIsomorphicLayoutEffect(() => {
    const list = listRef.current;
    if (!list || typeof list.querySelectorAll !== 'function') return;
    if (list.ownerDocument !== document) {
      injectGlobalStyles(list.ownerDocument);
    }
    if (!ordered) return;
    const boxes = Array.from(
      list.querySelectorAll<HTMLElement>(
        `:scope > li > [${ENRM_LIST_MARKER_ATTR}] > span`
      )
    );
    const measure = () => {
      let widest = 0;
      for (const box of boxes) widest = Math.max(widest, box.offsetWidth);
      const sizer = boxes[0]?.lastElementChild as HTMLElement | null;
      const base = sizer?.offsetWidth ?? 0;
      setSize((previous) =>
        !widest
          ? null
          : previous?.widest === widest && previous.base === base
            ? previous
            : { widest, base }
      );
    };
    measure();
    if (typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(measure);
    boxes.forEach((box) => observer.observe(box));
    return () => observer.disconnect();
  }, [listRef, ordered, itemCount, listStyle]);
  return ordered ? size : null;
}

function ListMarker({
  list,
  style,
  index,
  top,
}: {
  list: ListInfo;
  style: RendererProps['style'];
  index: number;
  top: number;
}) {
  const cell = {
    [ENRM_LIST_MARKER_ATTR]: true,
    'aria-hidden': true,
    'style': listMarkerStyle(style, list.column, top),
  };
  if (!list.ordered) {
    return (
      <span {...cell}>
        <span style={bulletStyle(style, list.depth)} />
      </span>
    );
  }
  return (
    <span {...cell}>
      <span style={orderedMarkerStyle(style)}>
        <span style={ORDERED_MARKER_NUMBER_STYLE}>
          {`${list.start + index}.`}
        </span>
        <span style={ORDERED_MARKER_SIZER_STYLE}>99.</span>
      </span>
    </span>
  );
}

function UnorderedListRenderer(props: RendererProps) {
  return <ListRenderer {...props} listTag="ul" />;
}

function OrderedListRenderer(props: RendererProps) {
  return <ListRenderer {...props} listTag="ol" />;
}

function isNestedList(child: ASTNode): boolean {
  return NESTED_LIST_TYPES.has(child.type);
}

function ListItemRenderer({
  node,
  style,
  styles,
  index,
  callbacks,
  capabilities,
  renderChildren,
}: RendererProps) {
  const list = useContext(ListContext);
  const isTask = node.attributes?.isTask === 'true';
  const initialChecked = node.attributes?.taskChecked === 'true';
  const taskText = isTask ? extractNodeText(node) : '';
  const [isChecked, setIsChecked] = useState(initialChecked);

  useEffect(() => {
    setIsChecked(initialChecked);
  }, [initialChecked]);

  const handleChange = () => {
    if (!capabilities.enableTaskListItemToggle) return;

    const taskIndex = node.attributes?.taskIndex;
    if (taskIndex === undefined) return;

    const newChecked = !isChecked;
    setIsChecked(newChecked);

    callbacks.onTaskListItemPress?.({
      index: taskIndex,
      checked: newChecked,
      text: taskText,
    });
  };

  const hasNestedList = node.children?.some(isNestedList);
  const checkedStyle =
    isTask && isChecked ? checkedTaskTextStyle(style) : undefined;

  const inlineNode: ASTNode = hasNestedList
    ? {
        ...node,
        children: node.children?.filter((child) => !isNestedList(child)),
      }
    : node;
  const nestedNode: ASTNode | null = hasNestedList
    ? { ...node, children: node.children?.filter(isNestedList) }
    : null;

  const marker =
    !isTask && list ? (
      <ListMarker
        list={list}
        style={style}
        index={index ?? 0}
        top={
          inlineNode.children?.[0]?.type === 'CodeBlock'
            ? leadingCodeBlockMarkerTop(style)
            : 0
        }
      />
    ) : null;
  const nestedOffset = !(marker && list)
    ? style.list.marginLeft
    : inlineNode.children?.length
      ? style.list.marginLeft - list.baseColumn - listGap(style)
      : Math.max(0, style.list.marginLeft - list.baseColumn - listGap(style));
  return (
    <li
      style={listItemStyle(
        style,
        isTask,
        (index ?? 0) === 0,
        list?.column ?? 0
      )}
    >
      {marker}
      <span style={checkedStyle}>
        {isTask && (
          <input
            type="checkbox"
            className={ENRM_TASK_CHECKBOX_CLASS}
            checked={isChecked}
            onChange={handleChange}
            readOnly={!capabilities.enableTaskListItemToggle}
            aria-disabled={
              capabilities.enableTaskListItemToggle ? undefined : true
            }
            style={{
              ...styles.taskCheckbox,
              ...(isChecked && styles.taskCheckboxChecked),
              ...(!capabilities.enableTaskListItemToggle &&
                TASK_CHECKBOX_INERT_STYLE),
            }}
            aria-label={`Task: ${taskText}`}
          />
        )}
        {renderChildren(inlineNode)}
      </span>
      {nestedNode && (
        <NestedListOffsetContext.Provider value={nestedOffset}>
          {renderChildren(nestedNode)}
        </NestedListOffsetContext.Provider>
      )}
    </li>
  );
}

export const listRenderers: RendererMap = {
  UnorderedList: UnorderedListRenderer,
  OrderedList: OrderedListRenderer,
  ListItem: ListItemRenderer,
};
