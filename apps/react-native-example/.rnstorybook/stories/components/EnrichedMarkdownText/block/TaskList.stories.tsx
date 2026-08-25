import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  githubFlavorArgTypes,
  taskListStyledDefaults,
  type TaskListStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toTaskListStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const MARKDOWN = `- [x] Dice 2 onions, 3 celery stalks, and parsnips
- [x] Add vegetables to the pot
- [ ] Add ground pork and beef
- [ ] Saute for 10 minutes
- [ ] Pour in passata and simmer for 1 hour
- [x] Boil spaghetti pasta
- [ ] Mix everything and serve`;

const NESTED_MARKDOWN = `- [x] Buy groceries
  - [x] Vegetables
  - [ ] Fruit
- [ ] Cook dinner
  - [x] Prep ingredients
  - [ ] Serve
- [x] Wash dishes`;

type TaskListDemoControls = TaskListStyleControls & { itemSpacing: number };

const taskListDemoDefaults: TaskListDemoControls = {
  ...taskListStyledDefaults,
  itemSpacing: 0,
};

const argTypes = {
  ...githubFlavorArgTypes('Task lists require flavor="github" (GFM).'),
  itemSpacing: numberControl('markdownStyle.list.itemSpacing', {
    min: 0,
    max: 32,
    step: 2,
  }),
  checkedColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkedColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.taskList.borderColor',
  },
  checkboxSize: numberControl('markdownStyle.taskList.checkboxSize', {
    min: 12,
    max: 28,
    step: 1,
  }),
  checkboxBorderRadius: numberControl(
    'markdownStyle.taskList.checkboxBorderRadius',
    { min: 0, max: 12, step: 1 }
  ),
  checkmarkColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkmarkColor',
  },
  checkedTextColor: {
    control: 'color',
    description: 'markdownStyle.taskList.checkedTextColor',
  },
  checkedStrikethrough: {
    control: 'boolean',
    description: 'markdownStyle.taskList.checkedStrikethrough',
  },
  onTaskListItemPress: { action: 'onTaskListItemPress' },
};

function renderTaskList(
  title: string,
  description: string,
  args: StoryArgs<TaskListDemoControls>
) {
  const { controls, rest } = splitStyleControls(args, taskListDemoDefaults);
  const { itemSpacing, ...taskListControls } = controls;
  return (
    <EnrichedMarkdownTextStory
      title={title}
      description={description}
      {...rest}
      style={{
        taskList: toTaskListStyle(taskListControls),
        list: { itemSpacing },
      }}
    />
  );
}

const taskListStoryBase = {
  argTypes,
  args: {
    flavor: 'github' as const,
    ...taskListDemoDefaults,
  },
};

export default storyMeta('Block', 'Task List');

export const Default: TextStory<TaskListDemoControls> = {
  ...taskListStoryBase,
  args: {
    ...taskListStoryBase.args,
    markdown: MARKDOWN,
  },
  render: (args) =>
    renderTaskList(
      'Task List',
      'GFM task lists. Tap checkboxes to fire onTaskListItemPress (Actions panel). Use the controls to tune markdownStyle.taskList.',
      args
    ),
};

export const Nested: TextStory<TaskListDemoControls> = {
  ...taskListStoryBase,
  args: {
    ...taskListStoryBase.args,
    markdown: NESTED_MARKDOWN,
  },
  render: (args) =>
    renderTaskList(
      'Nested Task List',
      'Nest task items with indentation. Tap checkboxes to fire onTaskListItemPress (Actions panel).',
      args
    ),
};
