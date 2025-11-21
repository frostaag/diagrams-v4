import { X, Download, ExternalLink, Calendar } from 'lucide-react';
import type { Diagram } from '@/types/diagram';
import { getDiagramImageUrl } from '@/services/diagramService';

interface DiagramModalProps {
  diagram: Diagram | null;
  isOpen: boolean;
  onClose: () => void;
}

export function DiagramModal({ diagram, isOpen, onClose }: DiagramModalProps) {
  if (!isOpen || !diagram) return null;

  const imageUrl = getDiagramImageUrl(diagram);
  
  const handleDownload = () => {
    const link = document.createElement('a');
    link.href = imageUrl;
    link.download = diagram.currentPngFile;
    link.click();
  };
  
  const handleOpenInNewTab = () => {
    window.open(imageUrl, '_blank');
  };
  
  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
        onClick={onClose}
      />
      
      {/* Modal */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div className="relative w-full max-w-6xl bg-white rounded-lg shadow-xl">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
            <div className="flex items-center gap-3">
              <span className="inline-flex items-center px-3 py-1 rounded text-sm font-medium bg-sap-blue text-white">
                {diagram.id}
              </span>
              <h2 className="text-xl font-semibold text-gray-900">
                {diagram.name}
              </h2>
            </div>
            
            <button
              onClick={onClose}
              className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          
          {/* Content */}
          <div className="p-6">
            {/* Image */}
            <div className="mb-6 bg-gray-50 rounded-lg overflow-hidden">
              <img
                src={imageUrl}
                alt={diagram.name}
                className="w-full h-auto"
              />
            </div>
            
            {/* Details */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <div>
                <h3 className="text-sm font-semibold text-gray-700 mb-3">Details</h3>
                <dl className="space-y-2">
                  <div className="flex items-center gap-2 text-sm">
                    <dt className="text-gray-500 min-w-24">Category:</dt>
                    <dd className="font-medium text-gray-900">{diagram.category}</dd>
                  </div>
                  <div className="flex items-center gap-2 text-sm">
                    <dt className="text-gray-500 min-w-24">Version:</dt>
                    <dd className="font-medium text-gray-900">{diagram.currentVersion}</dd>
                  </div>
                  <div className="flex items-center gap-2 text-sm">
                    <dt className="text-gray-500 min-w-24">All Versions:</dt>
                    <dd className="font-medium text-gray-900">{diagram.versions.join(', ')}</dd>
                  </div>
                </dl>
              </div>
              
              <div>
                <h3 className="text-sm font-semibold text-gray-700 mb-3">Timeline</h3>
                <dl className="space-y-2">
                  <div className="flex items-start gap-2 text-sm">
                    <Calendar className="w-4 h-4 text-gray-400 mt-0.5" />
                    <div>
                      <dt className="text-gray-500">Created:</dt>
                      <dd className="font-medium text-gray-900">
                        {new Date(diagram.created).toLocaleDateString()}
                      </dd>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 text-sm">
                    <Calendar className="w-4 h-4 text-gray-400 mt-0.5" />
                    <div>
                      <dt className="text-gray-500">Last Modified:</dt>
                      <dd className="font-medium text-gray-900">
                        {new Date(diagram.lastModified).toLocaleDateString()}
                      </dd>
                    </div>
                  </div>
                </dl>
              </div>
            </div>
            
            {/* Actions */}
            <div className="flex items-center gap-3 pt-4 border-t border-gray-200">
              <button
                onClick={handleDownload}
                className="inline-flex items-center gap-2 px-4 py-2 bg-sap-blue text-white rounded-lg hover:bg-sap-dark-blue transition-colors"
              >
                <Download className="w-4 h-4" />
                Download
              </button>
              <button
                onClick={handleOpenInNewTab}
                className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <ExternalLink className="w-4 h-4" />
                Open in New Tab
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
