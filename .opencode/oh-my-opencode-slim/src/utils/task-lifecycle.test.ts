import { describe, expect, test } from 'bun:test';
import { BackgroundJobBoard } from './background-job-board';
import { parseTaskStatusOutput } from './task';

function cancellationOutput(taskID: string): string {
  return [
    `task_id: ${taskID}`,
    'state: cancelled',
    '',
    '<task_error>',
    'Task cancelled',
    '</task_error>',
  ].join('\n');
}

describe('task return-channel lifecycle classification', () => {
  test('keeps a live task cancellation receipt return-channel-pending', () => {
    const board = new BackgroundJobBoard();
    board.registerLaunch({
      taskID: 'ses_live',
      parentSessionID: 'parent-1',
      agent: 'coder',
    });

    board.updateFromStatusOutput(cancellationOutput('ses_live'));

    expect(board.get('ses_live')).toMatchObject({
      state: 'return-channel-pending',
      cancellationRequested: false,
    });
  });

  test('does not classify cancellation as terminal without a cancellation request', () => {
    const board = new BackgroundJobBoard();
    board.registerLaunch({
      taskID: 'ses_unrequested',
      parentSessionID: 'parent-1',
      agent: 'coder',
    });

    board.updateStatus({ taskID: 'ses_unrequested', state: 'cancelled' });

    expect(board.get('ses_unrequested')).toMatchObject({
      state: 'return-channel-pending',
      cancellationRequested: false,
      terminalState: undefined,
    });
  });

  test('classifies cancellation as terminal only with both board confirmations', () => {
    const board = new BackgroundJobBoard();
    board.registerLaunch({
      taskID: 'ses_confirmed',
      parentSessionID: 'parent-1',
      agent: 'coder',
    });

    board.markCancelled('ses_confirmed', 'user requested');

    expect(board.get('ses_confirmed')).toMatchObject({
      state: 'cancelled',
      terminalState: 'cancelled',
      cancellationRequested: true,
    });
  });
});

describe('legacy task return-channel parsing', () => {
  test.each([
    ['running', 'task result is still in flight'],
    ['completed', 'task result is complete'],
    ['error', 'task failed'],
  ] as const)('preserves the %s state and result semantics', (state, result) => {
    const parsed = parseTaskStatusOutput(
      [
        'task_id: ses_legacy',
        `state: ${state}`,
        '',
        '<task_result>',
        result,
        '</task_result>',
      ].join('\n'),
    );

    expect(parsed).toEqual({
      taskID: 'ses_legacy',
      state,
      timedOut: false,
      result,
    });
  });
});
