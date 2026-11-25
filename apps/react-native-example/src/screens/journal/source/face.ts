import { createContext, useContext, useRef } from 'react';

// Whether the side of a switchable block this is on is out of sight.
export const FaceHidden = createContext(false);

// Out of sight, a block arrives finished: its entrances skip to the end, so
// the page never switches to a card caught halfway in. Read `.current` when an
// animation starts; the face can turn while the component lives.
export function useInstant() {
  const hidden = useContext(FaceHidden);
  const instant = useRef(hidden);
  instant.current = hidden;
  return instant;
}
