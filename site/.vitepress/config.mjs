import { fileURLToPath } from "node:url";
import { defineConfig } from "vitepress";

// Screenshots, Mom's portrait, and the errand data live in the Godot project, outside site/.
const game = (path) => fileURLToPath(new URL(`../../${path}`, import.meta.url));

const itch = "https://dustinmichels.itch.io/stroad-hero";
const github = "https://github.com/dustinmichels/stroad-hero";

export default defineConfig({
  title: "Stroad Hero",
  description:
    "Help Mats run his mom's errands across a four-lane stroad without going splat. A satirical Godot game about car-dependent American streets.",
  head: [["link", { rel: "icon", type: "image/svg+xml", href: "/icon.svg" }]],

  themeConfig: {
    logo: "/icon.svg",
    nav: [
      { text: "Manual", link: "/guide/", activeMatch: "/guide/" },
      { text: "Play on itch.io", link: itch },
    ],
    sidebar: {
      "/guide/": [
        {
          text: "Playing",
          items: [
            { text: "Getting started", link: "/guide/" },
            { text: "Errands and scoring", link: "/guide/errands" },
            { text: "Controls", link: "/guide/controls" },
            { text: "Getting around", link: "/guide/getting-around" },
            { text: "Customizing Mats", link: "/guide/customizer" },
          ],
        },
        {
          text: "The world",
          items: [
            { text: "The neighborhood", link: "/guide/neighborhood" },
            { text: "Traffic", link: "/guide/traffic" },
            { text: "Retro styles and display", link: "/guide/display" },
          ],
        },
        {
          text: "Development",
          items: [
            { text: "Building from source", link: "/guide/building" },
            { text: "Debug keys", link: "/guide/debug" },
          ],
        },
      ],
    },
    socialLinks: [{ icon: "github", link: github }],
    search: { provider: "local" },
    outline: "deep",
    footer: {
      message: "Made by Dustin Michels in Godot.",
    },
  },

  vite: {
    resolve: {
      // Vue rewrites relative asset paths to URLs in dev; an alias makes them real imports in dev and build.
      alias: { "@screenshots": game("screenshots") },
    },
    server: {
      fs: {
        allow: [
          fileURLToPath(new URL("..", import.meta.url)),
          game("screenshots"),
          game("ui/mom_portrait.png"),
          game("objectives/mats_objectives.json"),
        ],
      },
    },
  },
});
