import type { Metadata, Viewport } from "next";
import "./globals.css";\nimport RegisterSW from "./register-sw";

export const metadata: Metadata = {
  title: "shikarisøkesearch",
  description: "Washington-first real estate intelligence and property research",
  applicationName: "shikarisøkesearch",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "Shikarisøkesearch", statusBarStyle: "black-translucent" }
};
export const viewport: Viewport = { themeColor: "#101c27", width: "device-width", initialScale: 1 };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body><RegisterSW />{children}</body></html>;
}
