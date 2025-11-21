# Fiori UI Specification for Diagram Viewer Application

## Application Overview
A **SAP Fiori application** that displays technical diagrams stored in SAP Document Management Service (DMS), allowing users to browse, search, filter, view, and download SVG diagrams with full metadata support.

---

## Core Requirements

### Data Source
- **Backend**: SAP Document Management Service (DMS) via CMIS API
- **Authentication**: OAuth2 via SAP Destination Service
- **Content Type**: SVG diagram files with inherited metadata
- **API Endpoint**: Available via destination `DMS_DESTINATION`

### Key Metadata Fields (from DMS)
- `cmis:objectId` - Unique document ID
- `cmis:name` - File name (e.g., "002_SAP Cloud_v15.svg")
- `cmis:description` - Inherited description from parent folder
- `cmis:createdBy` - Author
- `cmis:creationDate` - Creation timestamp
- `cmis:lastModificationDate` - Last modified timestamp
- `cmis:contentStreamLength` - File size
- Custom properties:
  - `diagramId` (extracted from filename, e.g., "002")
  - `diagramName` (e.g., "SAP Cloud")
  - `version` (e.g., "v15")
  - `category` (from folder description)

---

## UI/UX Design Specifications

### 1. Application Shell

**Layout**: SAP Fiori 3 Shell Bar
- **App Title**: "Technical Diagrams Viewer"
- **Shell Bar Actions**:
  - User Menu (right corner)
  - Settings/About (optional)
- **Responsive**: Support desktop, tablet, mobile

---

### 2. Main View - Master-Detail Pattern

#### Master Panel (Left Side - 40% width)

**Header Section**:
```
┌────────────────────────────────────────┐
│ 🔍 Search Diagrams                      │
│ [                              ] 🔎     │
├────────────────────────────────────────┤
│ Filters:                                │
│ □ Category Filter (Dropdown)           │
│ □ Date Range (From/To)                 │
│ □ Author Filter                         │
│ [Clear Filters] [Apply]                │
└────────────────────────────────────────┘
```

**List Section** (sap.m.List with sap.m.StandardListItem):
```
┌────────────────────────────────────────┐
│ Results: 24 diagrams                    │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │ 📊 002 - SAP Cloud (v15)          │ │
│ │ Category: Cloud Infrastructure     │ │
│ │ Modified: 2024-11-20              │ │
│ │ Size: 245 KB                      │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 📊 005 - Integration Flow (v3)    │ │
│ │ Category: Integration             │ │
│ │ Modified: 2024-11-19              │ │
│ │ Size: 156 KB                      │ │
│ └────────────────────────────────────┘ │
│ [Load More...]                         │
└────────────────────────────────────────┘
```

**List Item Design**:
- **Title**: `{diagramId} - {diagramName} ({version})`
- **Description Line 1**: `Category: {category}` (from folder description)
- **Description Line 2**: `Modified: {lastModificationDate | formatDate}`
- **Info**: `Size: {fileSize | formatFileSize}`
- **Type**: `Active` (clickable)
- **Icon**: Document icon or custom diagram icon
- **Press Event**: Load diagram in detail panel

**States**:
- **Selected**: Highlight with SAP's primary selection color
- **Hover**: Subtle background change
- **Loading**: Busy indicator while fetching

---

#### Detail Panel (Right Side - 60% width)

**When No Selection**:
```
┌─────────────────────────────────────────┐
│                                         │
│         📊                              │
│    Select a diagram                     │
│    to view details                      │
│                                         │
└─────────────────────────────────────────┘
```

**When Diagram Selected**:
```
┌─────────────────────────────────────────┐
│ Header:                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 📊 002 - SAP Cloud (v15)            │ │
│ │ [⬇ Download] [🔗 Share] [ℹ️ Info]    │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ SVG Display Area:                       │
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │     [SVG Diagram Rendered]          │ │
│ │                                     │ │
│ │     (Scrollable if needed)          │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Metadata Panel (Collapsible):          │
│ ▼ Details                               │
│ ┌─────────────────────────────────────┐ │
│ │ Category: Cloud Infrastructure      │ │
│ │ Description: [Full description]     │ │
│ │ Created: 2024-01-15 by John Doe    │ │
│ │ Modified: 2024-11-20 10:45 AM      │ │
│ │ File Size: 245 KB                  │ │
│ │ Version: v15                        │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Detail Panel Components**:

1. **Title Bar** (sap.m.Bar):
   - Main Title: `{diagramId} - {diagramName} ({version})`
   - Action Buttons:
     - **Download** - Downloads SVG file
     - **Share** - Copy link to clipboard
     - **Info** - Toggle metadata panel

2. **SVG Display Area** (sap.m.ScrollContainer):
   - **Full Width/Height**: Fill available space
   - **Background**: White or light gray
   - **Border**: Subtle border
   - **Zoom Controls**: 
     - Zoom in/out buttons
     - Fit to width button
     - Reset zoom button
   - **Pan**: Allow dragging to pan large diagrams

3. **Metadata Panel** (sap.m.Panel - expandable):
   - **Collapsed by default** on mobile
   - **Expanded by default** on desktop
   - Display all metadata in labeled fields:
     ```
     Category:      Cloud Infrastructure
     Description:   [Full folder description]
     Diagram ID:    002
     Version:       v15
     Created By:    John Doe
     Created Date:  Jan 15, 2024, 10:30 AM
     Modified Date: Nov 20, 2024, 10:45 AM
     File Size:     245 KB
     Document ID:   {cmis:objectId}
     ```

---

### 3. Search & Filter Functionality

**Search Bar** (sap.m.SearchField):
- **Placeholder**: "Search by name, ID, or description..."
- **Search Triggers**:
  - On Enter key
  - On search button click
  - Live search after 3 characters (debounced)
- **Search Fields**: diagram name, diagram ID, description, category

**Filter Panel** (sap.ui.comp.filterbar.FilterBar):

**Filter Fields**:
1. **Category** (sap.m.MultiComboBox)
   - Options: Dynamically loaded from unique categories in DMS
   - Multi-select enabled
   - Example: "Cloud Infrastructure", "Integration", "Security"

2. **Date Range** (sap.m.DateRangeSelection)
   - Filter by modification date
   - Show: "From [date] to [date]"

3. **Author** (sap.m.MultiComboBox)
   - Options: Dynamically loaded from unique authors
   - Multi-select enabled

4. **Version Filter** (sap.m.Input)
   - Filter by specific version (e.g., "v15")
   - Optional field

**Filter Actions**:
- **"Go" Button**: Apply filters
- **Clear Button**: Reset all filters
- **Adapt Filters**: Allow user to show/hide filter fields

**Active Filters Display** (sap.m.Toolbar):
- Show applied filters as tokens
- Example: `[Category: Cloud] [Modified: Last 7 days] [×]`
- Each token removable

---

### 4. Responsive Behavior

**Desktop (>1024px)**:
- Master-Detail side-by-side (40/60 split)
- All filters visible
- Metadata panel expanded by default

**Tablet (768-1024px)**:
- Master-Detail side-by-side (45/55 split)
- Filters in popover
- Metadata panel collapsible

**Mobile (<768px)**:
- **Master View**: Full screen list
- **Detail View**: Full screen when diagram selected
- **Back Button**: Return to list
- **Filters**: In dialog/popover
- **Metadata**: Collapsible panel at bottom

---

### 5. Loading & Error States

**Loading States**:
```
┌─────────────────────────────────────┐
│        ⏳ Loading diagrams...       │
│                                     │
│     [Busy Indicator Animation]     │
└─────────────────────────────────────┘
```

**Empty State** (No Results):
```
┌─────────────────────────────────────┐
│          📭                         │
│    No diagrams found                │
│                                     │
│    Try adjusting your filters      │
│    or search criteria              │
└─────────────────────────────────────┘
```

**Error State**:
```
┌─────────────────────────────────────┐
│          ⚠️                         │
│    Failed to load diagrams          │
│                                     │
│    Error: [Error message]          │
│    [Retry] [Contact Support]       │
└─────────────────────────────────────┘
```

**Individual Diagram Load Error**:
- Show placeholder in SVG area
- Display error message: "Failed to load diagram"
- Offer retry button

---

### 6. Actions & Interactions

**Download Action**:
- **Click "Download" button**
- Downloads SVG file with original filename
- Shows success message: "Diagram downloaded successfully"

**Share Action**:
- **Click "Share" button**
- Copies direct link to clipboard
- Shows toast: "Link copied to clipboard"
- Link format: `https://[app-url]/diagram/{documentId}`

**View Toggle**:
- **List View** (default)
- **Grid View** (optional): Cards with thumbnail previews

**Sorting** (sap.m.ViewSettingsDialog):
- Sort by:
  - Name (A-Z, Z-A)
  - Modified Date (Newest, Oldest)
  - File Size (Largest, Smallest)
  - Diagram ID (Ascending, Descending)

---

### 7. Technical Implementation Details

**OData Service** (Required):
Create an OData V4 service that wraps the CMIS API:

```javascript
// Entity: Diagram
{
  id: String (primary key),
  diagramId: String,
  name: String,
  description: String,
  category: String,
  version: String,
  createdBy: String,
  createdDate: DateTime,
  modifiedDate: DateTime,
  fileSize: Integer,
  contentUrl: String,
  cmisObjectId: String
}

// Operations:
GET /Diagrams - List all diagrams
GET /Diagrams('{id}') - Get single diagram
GET /Diagrams('{id}')/content - Get SVG content
GET /Diagrams/$count - Get total count
```

**Fiori Elements Template**:
Use **List Report + Object Page** template:
- **List Report**: Master list with search/filter
- **Object Page**: Detail view with SVG and metadata

**Or Custom Fiori App**:
Use **SAPUI5** with:
- `sap.m.SplitApp` for master-detail
- `sap.m.List` for diagram list
- `sap.m.Panel` for detail view
- `sap.ui.core.HTML` or custom SVG control for rendering

---

### 8. Color Scheme & Styling

**Follow SAP Fiori 3 Design**:
- **Primary Color**: SAP Blue (#0854A0)
- **Background**: White (#FFFFFF) or Light Gray (#F7F7F7)
- **Text**: Dark Gray (#32363A)
- **Borders**: Light Gray (#D9D9D9)
- **Selected Item**: SAP Blue with 10% opacity
- **Hover State**: Light gray background

**Custom Styling for SVG Display**:
```css
.diagram-container {
  background: #FFFFFF;
  border: 1px solid #D9D9D9;
  border-radius: 4px;
  padding: 16px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.diagram-svg {
  max-width: 100%;
  height: auto;
  display: block;
}
```

---

### 9. Accessibility Requirements

- **ARIA Labels**: All interactive elements
- **Keyboard Navigation**: Full support
- **Screen Reader**: Compatible
- **High Contrast Mode**: Support SAP's high contrast themes
- **Focus Indicators**: Clear visual focus
- **Alt Text**: For all images/diagrams

---

### 10. Performance Considerations

**Pagination**:
- Load 20 diagrams initially
- **"Load More"** button or infinite scroll
- Display total count: "Showing 20 of 124"

**Lazy Loading**:
- Only load SVG content when diagram is selected
- Cache loaded diagrams in browser

**Thumbnail Generation** (Optional Enhancement):
- Generate and cache small PNG thumbnails for grid view
- Store thumbnails in DMS or browser cache

**Offline Support** (Optional):
- Cache recently viewed diagrams
- Show offline indicator when disconnected

---

## Priority Features (MVP)

### Must Have:
1. ✅ List all diagrams from DMS
2. ✅ Display SVG diagrams
3. ✅ Show metadata (category, date, size)
4. ✅ Search by name/ID
5. ✅ Download SVG files
6. ✅ Responsive design (desktop + mobile)
7. ✅ Category filter
8. ✅ Date filter

### Should Have:
1. ⭐ Share/copy link functionality
2. ⭐ Sort by multiple fields
3. ⭐ Grid view option
4. ⭐ Zoom/pan controls for SVG
5. ⭐ Author filter
6. ⭐ Version history view

### Nice to Have:
1. 💡 Thumbnail previews
2. 💡 Offline support
3. 💡 Favorites/bookmarks
4. 💡 Compare diagrams side-by-side
5. 💡 Export to PNG/PDF
6. 💡 Comments/annotations

---

## Instructions for SAP Build Code

### Step-by-Step Implementation Guide:

1. **Create a new Fiori application** using the **List Report + Object Page** template

2. **Connect to OData service** (you'll need to create this first to wrap the CMIS API)

3. **Configure the List Report**:
   - Entity: `Diagram`
   - Display fields: diagramId, name, category, modifiedDate, fileSize
   - Enable search on: name, diagramId, description
   - Add filters: category, dateRange, author

4. **Configure the Object Page**:
   - Header: Display diagram name and version
   - Section 1: SVG display (custom fragment)
   - Section 2: Metadata (form with all fields)
   - Actions: Download, Share

5. **Add custom SVG rendering logic** in a controller extension

6. **Style** according to Fiori 3 guidelines

7. **Test responsive behavior** on different devices

8. **Deploy** to SAP BTP Cloud Foundry

---

## Quick Start Prompt for SAP Build Code

Copy and paste this into SAP Build Code:

```
Create a SAP Fiori application for viewing technical diagrams stored in SAP DMS.

Requirements:
- Master-Detail layout with diagram list (left) and detail view (right)
- Connect to existing DMS via CMIS API through destination "DMS_DESTINATION"
- Display SVG diagrams with metadata: ID, name, category, version, dates, size
- Search by name/ID/description
- Filter by category, date range, author
- Download and share functionality
- Responsive design (desktop/tablet/mobile)
- Use SAP Fiori 3 design guidelines

Entity Structure:
- Diagram (id, diagramId, name, description, category, version, createdBy, createdDate, modifiedDate, fileSize, contentUrl, cmisObjectId)

UI Components:
- sap.m.SplitApp for master-detail
- sap.m.List for diagram list
- sap.m.ScrollContainer for SVG display
- sap.m.Panel for metadata
- Search and filter bar with MultiComboBox for categories/authors

Must support OAuth2 authentication via SAP Destination Service.
```

---

This specification provides everything needed to build a professional, SAP-standard diagram viewer application that integrates seamlessly with your existing DMS setup.
