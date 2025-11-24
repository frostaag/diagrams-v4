import { FileImage } from 'lucide-react';
import type { Diagram } from '@/types/diagram';
import { getDiagramImageUrl } from '@/services/diagramService';

interface DiagramCardProps {
  diagram: Diagram;
  onClick: () => void;
}

export function DiagramCard({ diagram, onClick }: DiagramCardProps) {
  // Use imageUrl from diagram if available (from DMS), otherwise get from local files
  const imageUrl = diagram.imageUrl || getDiagramImageUrl(diagram);
  
  return (
    <div
      onClick={onClick}
      className="group relative bg-white rounded-lg shadow-sm hover:shadow-md transition-all duration-200 cursor-pointer overflow-hidden border border-gray-200 hover:border-sap-blue"
    >
      {/* Image Container */}
      <div className="aspect-[4/3] bg-gray-50 flex items-center justify-center overflow-hidden">
        <img
          src={imageUrl}
          alt={diagram.name}
          className="w-full h-full object-contain group-hover:scale-105 transition-transform duration-200"
          loading="lazy"
        />
      </div>
      
      {/* Content */}
      <div className="p-4">
        {/* ID Badge */}
        <div className="flex items-center gap-2 mb-2">
          <span className="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-sap-blue text-white">
            {diagram.id}
          </span>
          <span className="text-xs text-gray-500">{diagram.currentVersion}</span>
        </div>
        
        {/* Title */}
        <h3 className="text-sm font-semibold text-gray-900 line-clamp-2 mb-2">
          {diagram.name}
        </h3>
        
        {/* Description */}
        <div className="flex items-center gap-1 text-xs text-gray-500">
          <FileImage className="w-3 h-3" />
          <span className="line-clamp-1">{diagram.description || 'No description'}</span>
        </div>
      </div>
      
      {/* Hover Overlay */}
      <div className="absolute inset-0 bg-sap-blue bg-opacity-0 group-hover:bg-opacity-5 transition-all duration-200 pointer-events-none" />
    </div>
  );
}
