export function renderVisualizerSSR(): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="400">
    <circle cx="400" cy="200" r="60" fill="none" stroke="#7c4dff" stroke-width="3"/>
    <line x1="320" y1="200" x2="480" y2="200" stroke="#b388ff" stroke-width="1.5" stroke-dasharray="4,4"/>
    <line x1="400" y1="120" x2="400" y2="280" stroke="#b388ff" stroke-width="1.5" stroke-dasharray="4,4"/>
  </svg>`;
}
