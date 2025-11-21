// Service to fetch diagrams from SAP Document Management Service
import type { Diagram } from '@/types/diagram';

// DMS Configuration - These should be set via environment variables
const DMS_CONFIG = {
  apiUrl: import.meta.env.VITE_DMS_API_URL || '',
  clientId: import.meta.env.VITE_DMS_CLIENT_ID || '',
  clientSecret: import.meta.env.VITE_DMS_CLIENT_SECRET || '',
  xsuaaUrl: import.meta.env.VITE_DMS_XSUAA_URL || '',
  repositoryId: import.meta.env.VITE_DMS_REPOSITORY_ID || '',
};

interface DMSDocument {
  succinctProperties: {
    'cmis:objectId': string;
    'cmis:name': string;
    'cmis:contentStreamMimeType': string;
    'cmis:contentStreamLength': number;
    'cmis:creationDate': number;
    'cmis:lastModificationDate': number;
  };
}

interface DMSListResponse {
  objects: DMSDocument[];
}

let cachedToken: string | null = null;
let tokenExpiry: number = 0;

/**
 * Get OAuth2 access token from XSUAA
 */
async function getAccessToken(): Promise<string> {
  // Return cached token if still valid (with 5 minute buffer)
  if (cachedToken && Date.now() < tokenExpiry - 300000) {
    return cachedToken;
  }

  const credentials = btoa(`${DMS_CONFIG.clientId}:${DMS_CONFIG.clientSecret}`);
  
  const response = await fetch(`${DMS_CONFIG.xsuaaUrl}/oauth/token`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });

  if (!response.ok) {
    throw new Error(`Failed to get access token: ${response.statusText}`);
  }

  const data = await response.json();
  cachedToken = data.access_token;
  // Set expiry (typically 12 hours, but we'll refresh earlier)
  tokenExpiry = Date.now() + ((data.expires_in || 43200) * 1000);
  
  return cachedToken!;
}

/**
 * Build the correct API URL based on whether repository ID is already in the base URL
 * Supports both formats:
 * - Old: https://api-sdm-di.cfapps.eu10.hana.ondemand.com + /browser/{repoId}/root
 * - New: https://api-sdm-di.cfapps.eu10.hana.ondemand.com/browser/{repoId} + /root
 */
function buildApiUrl(endpoint: string): string {
  const baseUrl = DMS_CONFIG.apiUrl;
  const repoId = DMS_CONFIG.repositoryId;
  
  // Check if the base URL already contains /browser/{repositoryId}
  if (baseUrl.includes(`/browser/${repoId}`)) {
    // New format: URL already has repository ID, just append endpoint
    return `${baseUrl}${endpoint}`;
  } else {
    // Old format: Need to add /browser/{repositoryId} before endpoint
    return `${baseUrl}/browser/${repoId}${endpoint}`;
  }
}

/**
 * List all documents in the DMS repository root
 */
async function listDocuments(): Promise<DMSDocument[]> {
  const token = await getAccessToken();
  
  const url = buildApiUrl('/root?cmisselector=children&succinct=true');
  
  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to list documents: ${response.statusText}`);
  }

  const data: DMSListResponse = await response.json();
  return data.objects || [];
}

/**
 * Get document content URL
 */
function getDocumentUrl(objectId: string, token: string | null): string {
  return buildApiUrl(`/root?objectId=${objectId}&cmisselector=content&download=inline&access_token=${token || ''}`);
}

/**
 * Parse diagram metadata from filename
 * Expected format: "002_SAP Cloud_v19.svg"
 */
function parseFilename(filename: string): { id: string; name: string; version: string } | null {
  const match = filename.match(/^(\d+)_(.+?)_v(\d+)\.svg$/);
  if (!match) return null;
  
  return {
    id: match[1],
    name: match[2],
    version: `v${match[3]}`,
  };
}

/**
 * Convert DMS document to Diagram object
 */
function dmsToDiagram(doc: DMSDocument, imageUrl: string): Diagram | null {
  const parsed = parseFilename(doc.succinctProperties['cmis:name']);
  if (!parsed) return null;

  return {
    id: parsed.id,
    name: parsed.name,
    originalName: doc.succinctProperties['cmis:name'],
    drawioFile: `${parsed.id}_${parsed.name}.drawio`,
    currentVersion: parsed.version,
    currentPngFile: doc.succinctProperties['cmis:name'],
    category: 'General', // We don't store category in DMS, could be enhanced
    created: new Date(doc.succinctProperties['cmis:creationDate']).toISOString(),
    lastModified: new Date(doc.succinctProperties['cmis:lastModificationDate']).toISOString(),
    versions: [parsed.version],
    status: 'active',
    imageUrl, // Add the image URL directly
  };
}

/**
 * Fetch all active diagrams from SAP DMS
 * Only returns the latest version of each diagram (based on filename)
 */
export async function getDiagramsFromDMS(): Promise<Diagram[]> {
  // Check if DMS is configured
  if (!DMS_CONFIG.apiUrl || !DMS_CONFIG.clientId) {
    console.warn('DMS not configured, returning empty list');
    return [];
  }

  try {
    const documents = await listDocuments();
    const token = await getAccessToken();
    
    // Filter only SVG files and convert to Diagram objects
    const diagrams: Diagram[] = documents
      .filter(doc => doc.succinctProperties['cmis:name'].endsWith('.svg'))
      .map(doc => {
        const imageUrl = getDocumentUrl(doc.succinctProperties['cmis:objectId'], token);
        return dmsToDiagram(doc, imageUrl);
      })
      .filter((d): d is Diagram => d !== null);

    // Sort by ID
    return diagrams.sort((a, b) => parseInt(a.id) - parseInt(b.id));
  } catch (error) {
    console.error('Failed to fetch diagrams from DMS:', error);
    throw error;
  }
}

/**
 * Check if DMS is configured
 */
export function isDMSConfigured(): boolean {
  return !!(DMS_CONFIG.apiUrl && DMS_CONFIG.clientId && DMS_CONFIG.clientSecret && DMS_CONFIG.xsuaaUrl);
}

/**
 * Group diagrams by category
 */
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

/**
 * Search diagrams
 */
export function searchDiagrams(diagrams: Diagram[], searchTerm: string): Diagram[] {
  const term = searchTerm.toLowerCase();
  return diagrams.filter(diagram =>
    diagram.id.toLowerCase().includes(term) ||
    diagram.name.toLowerCase().includes(term) ||
    diagram.category.toLowerCase().includes(term)
  );
}
