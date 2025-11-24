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

export function getVersionImageUrl(diagramId: string, diagramName: string, version: string): string {
  return `${PNG_BASE_PATH}${diagramId}_${diagramName}_${version}.svg`;
}

export function sortVersions(versions: string[]): string[] {
  return versions.sort((a, b) => {
    const numA = parseInt(a.replace('v', ''));
    const numB = parseInt(b.replace('v', ''));
    return numA - numB;
  });
}

// LocalStorage functions for description persistence
const DESCRIPTION_STORAGE_KEY = 'diagram-descriptions';

export function saveDescription(diagramId: string, description: string): void {
  try {
    const descriptions = JSON.parse(localStorage.getItem(DESCRIPTION_STORAGE_KEY) || '{}');
    descriptions[diagramId] = description;
    localStorage.setItem(DESCRIPTION_STORAGE_KEY, JSON.stringify(descriptions));
  } catch (error) {
    console.error('Failed to save description:', error);
  }
}

export function getDescription(diagramId: string): string | null {
  try {
    const descriptions = JSON.parse(localStorage.getItem(DESCRIPTION_STORAGE_KEY) || '{}');
    return descriptions[diagramId] || null;
  } catch (error) {
    console.error('Failed to get description:', error);
    return null;
  }
}

export async function getDiagramsWithDescriptions(): Promise<Diagram[]> {
  const diagrams = await getDiagrams();
  
  // Enrich with saved descriptions and sorted versions
  return diagrams.map(diagram => {
    const savedDescription = getDescription(diagram.id);
    const sortedVersions = sortVersions([...diagram.versions]);
    
    // Generate version URLs
    const versionUrls: Record<string, string> = {};
    sortedVersions.forEach(version => {
      versionUrls[version] = getVersionImageUrl(diagram.id, diagram.name, version);
    });
    
    return {
      ...diagram,
      description: savedDescription || diagram.category,
      versions: sortedVersions,
      versionUrls,
    };
  });
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
