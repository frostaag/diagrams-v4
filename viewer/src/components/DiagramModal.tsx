import { useState, useEffect } from 'react';
import { X, Download, ExternalLink, Calendar, Edit2, Save, Link, Check } from 'lucide-react';
import type { Diagram } from '@/types/diagram';
import { getDiagramImageUrl, saveDescription } from '@/services/diagramService';

interface DiagramModalProps {
  diagram: Diagram | null;
  isOpen: boolean;
  onClose: () => void;
  onDescriptionSaved?: () => void;
}

export function DiagramModal({ diagram, isOpen, onClose, onDescriptionSaved }: DiagramModalProps) {
  const [isEditingDescription, setIsEditingDescription] = useState(false);
  const [editedDescription, setEditedDescription] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [showSaved, setShowSaved] = useState(false);
  const [currentDescription, setCurrentDescription] = useState('');

  // Reset and initialize currentDescription when modal opens/closes or diagram changes
  useEffect(() => {
    if (isOpen && diagram) {
      setCurrentDescription(diagram.description || diagram.category || '');
    } else {
      setCurrentDescription('');
    }
  }, [isOpen, diagram?.id, diagram?.description]);

  if (!isOpen || !diagram) return null;

  // Use current description for display
  const description = currentDescription;

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
                <dl className="space-y-3">
                  {/* Editable Description */}
                  <div className="flex flex-col gap-2 text-sm">
                    <div className="flex items-center justify-between">
                      <dt className="text-gray-500 font-medium">Description:</dt>
                      {!isEditingDescription && (
                        <button
                          onClick={() => {
                            setIsEditingDescription(true);
                            setEditedDescription(description);
                          }}
                          className="text-sap-blue hover:text-sap-dark-blue transition-colors"
                          title="Edit description"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                    {isEditingDescription ? (
                      <div className="flex flex-col gap-2">
                        <textarea
                          value={editedDescription}
                          onChange={(e) => setEditedDescription(e.target.value)}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-sap-blue focus:border-sap-blue resize-none"
                          rows={3}
                          placeholder="Enter description..."
                        />
                        <div className="flex gap-2">
                          <button
                            onClick={() => {
                              setIsSaving(true);
                              // Save to localStorage
                              saveDescription(diagram.id, editedDescription);
                              
                              // Update current description immediately
                              setCurrentDescription(editedDescription);
                              
                              // Show saved indicator
                              setTimeout(() => {
                                setIsSaving(false);
                                setIsEditingDescription(false);
                                setShowSaved(true);
                                
                                // Call parent refetch to update the diagram for other instances
                                if (onDescriptionSaved) {
                                  onDescriptionSaved();
                                }
                                
                                // Hide saved indicator after 2 seconds
                                setTimeout(() => {
                                  setShowSaved(false);
                                }, 2000);
                              }, 300);
                            }}
                            disabled={isSaving}
                            className="inline-flex items-center gap-2 px-3 py-1.5 bg-sap-blue text-white text-sm rounded hover:bg-sap-dark-blue transition-colors disabled:opacity-50"
                          >
                            {showSaved ? (
                              <>
                                <Check className="w-3.5 h-3.5" />
                                Saved!
                              </>
                            ) : (
                              <>
                                <Save className="w-3.5 h-3.5" />
                                {isSaving ? 'Saving...' : 'Save'}
                              </>
                            )}
                          </button>
                          <button
                            onClick={() => setIsEditingDescription(false)}
                            className="px-3 py-1.5 bg-gray-200 text-gray-700 text-sm rounded hover:bg-gray-300 transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <dd className="font-medium text-gray-900">{description}</dd>
                    )}
                  </div>
                  
                  <div className="flex items-center gap-2 text-sm">
                    <dt className="text-gray-500 min-w-24">Current Version:</dt>
                    <dd className="font-medium text-gray-900">{diagram.currentVersion}</dd>
                  </div>
                  
                  {/* All Versions with Links */}
                  <div className="flex flex-col gap-2 text-sm">
                    <dt className="text-gray-500 font-medium">All Versions:</dt>
                    <dd className="flex flex-wrap gap-2">
                      {diagram.versions.map((version) => {
                        const versionUrl = diagram.versionUrls?.[version];
                        return (
                          <span
                            key={version}
                            className={`inline-flex items-center gap-1 px-2 py-1 rounded text-xs ${
                              version === diagram.currentVersion
                                ? 'bg-sap-blue text-white'
                                : 'bg-gray-100 text-gray-700'
                            }`}
                          >
                            {version}
                            {versionUrl && (
                              <a
                                href={versionUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="hover:opacity-75 transition-opacity"
                                title={`Open ${version} in DMS`}
                                onClick={(e) => e.stopPropagation()}
                              >
                                <Link className="w-3 h-3" />
                              </a>
                            )}
                          </span>
                        );
                      })}
                    </dd>
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
