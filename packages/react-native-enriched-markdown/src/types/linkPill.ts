export interface LinkPillContent {
  label?: string;
  iconUri?: string;
  /**
   * Tint for this link's icon. The variant's `pill.iconTintColor` is not applied
   * to an icon set here through `iconUri`.
   */
  iconTintColor?: string;
}
