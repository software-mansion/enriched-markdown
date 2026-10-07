# Syntax highlighting

A fence's info string picks the grammar. The code block below is dark, so tokens take GitHub's dark palette.

## Python

```python
from dataclasses import dataclass

@dataclass
class User:
    name: str
    age: int = 0

    def greet(self, other: "User") -> str:
        # Adults get the long form
        if other.age >= 18:
            return f"Hello, {other.name}!"
        return "Hi"
```

## TSX

```tsx
type Props = { count: number; onPress: () => void };

export function Counter({ count, onPress }: Props) {
  const label = count === 0 ? "Start" : `Count: ${count}`;
  return <Button title={label} onPress={onPress} />;
}
```

## Rust

```rust
use std::collections::HashMap;

fn word_counts(text: &str) -> HashMap<&str, usize> {
    let mut counts = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word).or_insert(0) += 1;
    }
    counts
}
```

## JSON

```json
{
  "name": "enriched-markdown",
  "private": true,
  "retries": 3,
  "tags": ["markdown", "android"]
}
```

## Shell

```sh
# Restore the grammars, then build
yarn install && node vendor/vendor-grammars.mjs
./gradlew assembleRelease && echo "Done in ${SECONDS}s"
```

## Nested blocks

Code inside a list item and a block quote is highlighted the same way:

1. Describe the service:

   ```yaml
   service:
     name: markdown-preview
     replicas: 2
     ports: [8080, 8443]
   ```

2. Start it:

   ```go
   func main() {
       http.HandleFunc("/", render)
       log.Fatal(http.ListenAndServe(":8080", nil))
   }
   ```

> Styles live next to the markup they belong to:
>
> ```css
> .code-block {
>   border-radius: 8px;
>   color: #f3f4f6 !important;
> }
> ```

## Plain blocks

A block with no language, or one no bundled grammar covers, keeps the code block color. There is no Kotlin grammar:

```kotlin
fun greet(name: String): String = "Hello, $name!"
```

```
no language here
```
