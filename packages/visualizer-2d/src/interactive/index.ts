import * as d3 from 'd3';

export interface VisualizerHandle {
  update: () => void;
  destroy: () => void;
}

export function initInteractiveVisualizer(
  selector: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  _orchestrator: any,
): VisualizerHandle {
  const el = d3.select(selector);

  el.html('');

  const svg = el.append('svg').attr('width', '100%').attr('height', '100%');

  const width = (el.node() as HTMLElement | null)?.clientWidth ?? 800;
  const height = (el.node() as HTMLElement | null)?.clientHeight ?? 400;

  svg
    .append('circle')
    .attr('cx', width / 2)
    .attr('cy', height / 2)
    .attr('r', 60)
    .attr('fill', 'none')
    .attr('stroke', '#7c4dff')
    .attr('stroke-width', 3);

  svg
    .append('line')
    .attr('x1', width / 2 - 80)
    .attr('y1', height / 2)
    .attr('x2', width / 2 + 80)
    .attr('y2', height / 2)
    .attr('stroke', '#b388ff')
    .attr('stroke-width', 1.5)
    .attr('stroke-dasharray', '4,4');

  svg
    .append('line')
    .attr('x1', width / 2)
    .attr('y1', height / 2 - 80)
    .attr('x2', width / 2)
    .attr('y2', height / 2 + 80)
    .attr('stroke', '#b388ff')
    .attr('stroke-width', 1.5)
    .attr('stroke-dasharray', '4,4');

  return {
    update() {
      /* stub — will re-draw on data change */
    },
    destroy() {
      el.html('');
    },
  };
}
