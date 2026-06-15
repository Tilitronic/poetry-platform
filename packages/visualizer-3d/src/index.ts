import { h, defineComponent, type PropType, onMounted, onUnmounted, ref } from 'vue';
import * as THREE from 'three';

export default defineComponent({
  name: 'Visualizer3D',
  props: {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    orchestrator: { type: Object as PropType<any>, required: false },
  },
  setup() {
    const container = ref<HTMLElement | null>(null);
    let scene: THREE.Scene | null = null;
    let camera: THREE.PerspectiveCamera | null = null;
    let renderer: THREE.WebGLRenderer | null = null;
    let animId = 0;

    onMounted(() => {
      if (!container.value) return;

      const w = container.value.clientWidth || 600;
      const h = container.value.clientHeight || 400;

      scene = new THREE.Scene();
      scene.background = new THREE.Color(0x1a1a2e);

      camera = new THREE.PerspectiveCamera(60, w / h, 0.1, 1000);
      camera.position.z = 5;

      renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setSize(w, h);
      container.value.appendChild(renderer.domElement);

      const geometry = new THREE.IcosahedronGeometry(1.5, 2);
      const material = new THREE.MeshStandardMaterial({
        color: 0x7c4dff,
        wireframe: true,
        metalness: 0.3,
        roughness: 0.7,
      });
      const mesh = new THREE.Mesh(geometry, material);
      scene.add(mesh);

      const light = new THREE.DirectionalLight(0xffffff, 2);
      light.position.set(1, 2, 3);
      scene.add(light);
      scene.add(new THREE.AmbientLight(0x404060));

      function animate() {
        animId = requestAnimationFrame(animate);
        mesh.rotation.x += 0.005;
        mesh.rotation.y += 0.01;
        renderer?.render(scene!, camera!);
      }
      animate();
    });

    onUnmounted(() => {
      cancelAnimationFrame(animId);
      renderer?.dispose();
    });

    return () =>
      h('div', {
        ref: container,
        style: { width: '100%', height: '100%', minHeight: '400px' },
      });
  },
});
