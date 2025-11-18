/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'sap-blue': '#0a6ed1',
        'sap-dark-blue': '#0854a0',
        'sap-gold': '#f0ab00',
        'sap-red': '#bb0000',
        'sap-green': '#107e3e',
        'sap-orange': '#d04a00',
        'sap-light-gray': '#f7f7f7',
        'sap-gray': '#89919a',
        'sap-dark-gray': '#32363a',
      },
      fontFamily: {
        'sap': ['72', 'Arial', 'Helvetica', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
