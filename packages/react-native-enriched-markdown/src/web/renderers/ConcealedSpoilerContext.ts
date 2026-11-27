import { createContext } from 'react';

/** True under a still-concealed spoiler: links and images there stay inert. */
export const ConcealedSpoilerContext = createContext(false);

/** True inside a link, so an image there stays link content (also through spoilers). */
export const InsideLinkContext = createContext(false);

/** True directly under a spoiler of images alone, where each image draws its own cover. */
export const ImageOnlySpoilerContext = createContext(false);
