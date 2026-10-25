import type { Metadata } from 'next';
import './styles.css';
export const metadata: Metadata = { title: 'Beyond the Known | Content Engine', description: 'Science, history and discovery content operations.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
