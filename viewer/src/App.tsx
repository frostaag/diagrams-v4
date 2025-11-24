import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, Folder, RefreshCw } from 'lucide-react';
import { DiagramCard } from '@/components/DiagramCard';
import { DiagramModal } from '@/components/DiagramModal';
import { getDiagramsFromDMS, isDMSConfigured, groupDiagramsByCategory, searchDiagrams } from '@/services/dmsService';
import { getDiagramsWithDescriptions, groupDiagramsByCategory as groupLocalDiagrams, searchDiagrams as searchLocalDiagrams } from '@/services/diagramService';
import type { Diagram } from '@/types/diagram';

function App() {
  const [selectedDiagram, setSelectedDiagram] = useState<Diagram | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Use DMS if configured, otherwise fall back to local files
  const useDMS = isDMSConfigured();
  
  const { data: diagrams = [], isLoading, error, refetch } = useQuery({
    queryKey: ['diagrams', useDMS ? 'dms' : 'local'],
    queryFn: useDMS ? getDiagramsFromDMS : getDiagramsWithDescriptions,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });

  const handleDiagramClick = (diagram: Diagram) => {
    setSelectedDiagram(diagram);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedDiagram(null);
  };

  const handleRefresh = () => {
    refetch();
  };

  const filteredDiagrams = searchTerm
    ? (useDMS ? searchDiagrams(diagrams, searchTerm) : searchLocalDiagrams(diagrams, searchTerm))
    : diagrams;

  const groupedDiagrams = useDMS ? groupDiagramsByCategory(filteredDiagrams) : groupLocalDiagrams(filteredDiagrams);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-sap-light-gray flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-sap-blue mx-auto mb-4"></div>
          <p className="text-gray-600">Loading diagrams...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-sap-light-gray flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-600 mb-4">Error loading diagrams</p>
          <button
            onClick={handleRefresh}
            className="px-4 py-2 bg-sap-blue text-white rounded-lg hover:bg-sap-dark-blue transition-colors"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-sap-light-gray">
      {/* Header */}
      <header className="bg-white shadow-sm border-b sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-sap-blue rounded-lg">
                <Folder className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">
                  FRoSTA Diagrams
                </h1>
                <p className="text-sm text-gray-600">
                  {diagrams.length} diagrams
                </p>
              </div>
            </div>

            <div className="flex items-center gap-4">
              {/* Refresh Button */}
              <button
                onClick={handleRefresh}
                className="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
                title="Refresh diagrams"
              >
                <RefreshCw className="w-5 h-5" />
              </button>

              {/* Search */}
              <div className="relative w-64">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Search className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="text"
                  placeholder="Search diagrams..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-sap-blue focus:border-sap-blue"
                />
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {filteredDiagrams.length === 0 ? (
          <div className="text-center py-12">
            <Search className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">
              {searchTerm ? 'No diagrams match your search.' : 'No diagrams found.'}
            </p>
          </div>
        ) : (
          <>
            {/* Category Sections */}
            {Array.from(groupedDiagrams.entries()).map(([category, categoryDiagrams]) => (
              <section key={category} className="mb-12">
                <div className="flex items-center gap-3 mb-6">
                  <h2 className="text-2xl font-bold text-gray-900">{category}</h2>
                  <span className="text-sm text-gray-500">
                    ({categoryDiagrams.length})
                  </span>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                  {categoryDiagrams.map((diagram) => (
                    <DiagramCard
                      key={diagram.id}
                      diagram={diagram}
                      onClick={() => handleDiagramClick(diagram)}
                    />
                  ))}
                </div>
              </section>
            ))}
          </>
        )}
      </main>

      {/* Modal */}
      <DiagramModal
        diagram={selectedDiagram}
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        onDescriptionSaved={refetch}
      />
    </div>
  );
}

export default App;
