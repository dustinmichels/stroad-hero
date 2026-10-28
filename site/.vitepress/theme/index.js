import "@fontsource-variable/overpass/wght.css";
import "@fontsource-variable/overpass/wght-italic.css";
import { h } from "vue";
import DefaultTheme from "vitepress/theme-without-fonts";
import ExitSign from "./ExitSign.vue";
import MomCall from "./MomCall.vue";
import StorePylons from "./StorePylons.vue";
import ScreenshotGallery from "./ScreenshotGallery.vue";
import "./custom.css";

export default {
  extends: DefaultTheme,
  Layout: () => h(DefaultTheme.Layout, null, { "home-hero-image": () => h(ExitSign) }),
  enhanceApp({ app }) {
    app.component("MomCall", MomCall);
    app.component("StorePylons", StorePylons);
    app.component("ScreenshotGallery", ScreenshotGallery);
  },
};
