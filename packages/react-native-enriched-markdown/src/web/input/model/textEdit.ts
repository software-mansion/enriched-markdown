// Carries both texts, so the same record can be replayed in either
// direction.
export interface TextEdit {
  editStart: number;
  deletedText: string;
  insertedText: string;
}
