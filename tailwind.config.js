/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        primary: "#6C63FF",
        secondary: "#00D4AA",
        danger: "#FF6B6B",
        warning: "#F59E0B",
        success: "#10B981",
        background: "#0f0c29",
        card: "#1a1548",
        border: "rgba(108,99,255,0.2)",
      },
      fontFamily: {
        sans: ["System", "sans-serif"],
      },
    },
  },
  plugins: [],
};
