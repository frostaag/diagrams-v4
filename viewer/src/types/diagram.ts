export interface Diagram {
  id: string;
  name: string;
  originalName: string;
  drawioFile: string;
  currentVersion: string;
  currentPngFile: string;
  category: string;
  created: string;
  lastModified: string;
  versions: string[];
  status: string;
}

export interface DiagramRegistry {
  nextId: number;
  version: string;
  created: string;
  lastUpdated: string;
  diagrams: Record<string, Diagram>;
}

export interface ChangelogEntry {
  date: string;
  time: string;
  diagramId: string;
  diagramName: string;
  action: string;
  version: string;
  commit: string;
  author: string;
  commitMessage: string;
  fileSize: string;
  pngPath: string;
}
