import type { DiagramRegistry, Diagram } from '@/types/diagram';

const REGISTRY_PATH = '/diagram-registry.json';
const PNG_BASE_PATH = '/png_files/';

export async function fetchDiagramRegistry(): Promise<DiagramRegistry> {
  const response = await fetch(REGISTRY_PATH);
  if (!response.ok) {
    throw new Error('Failed to fetch diagram registry');
  }
  return response.json();
}

export async function getDiagrams(): Promise<Diagram[]> {
  const registry = await fetchDiagramRegistry();
  return Object.values(registry.diagrams)
    .filter(diagram => diagram.status === 'active')
    .sort((a, b) => parseInt(a.id) - parseInt(b.id));
}

export function getDiagramImageUrl(diagram: Diagram): string {
  return `${PNG_BASE_PATH}${diagram.currentPngFile}`;
}

export function groupDiagramsByCategory(diagrams: Diagram[]): Map<string, Diagram[]> {
  const grouped = new Map<string, Diagram[]>();
  
  diagrams.forEach(diagram => {
    const category = diagram.category || 'General';
    if (!grouped.has(category)) {
      grouped.set(category, []);
    }
    grouped.get(category)!.push(diagram);
  });
  
  return grouped;
}

export function searchDiagrams(diagrams: Diagram[], searchTerm: string): Diagram[] {
  const term = searchTerm.toLowerCase();
  return diagrams.filter(diagram =>
    diagram.id.toLowerCase().includes(term) ||
    diagram.name.toLowerCase().includes(term) ||
    diagram.category.toLowerCase().includes(term)
  );
}
