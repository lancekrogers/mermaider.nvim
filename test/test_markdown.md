# Test Markdown with Mermaid Blocks

This file tests the markdown integration feature of mermaider.nvim.

## Simple Flowchart

Here's a basic flowchart:

```mermaid
graph TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great!]
    B -->|No| D[Debug]
    D --> B
```

## Sequence Diagram

This demonstrates a sequence diagram:

```mermaid
sequenceDiagram
    participant User
    participant Plugin
    participant Mermaid
    participant ImageNvim
    
    User->>Plugin: :MermaiderRenderBlock
    Plugin->>Mermaid: Render diagram
    Mermaid-->>Plugin: PNG file
    Plugin->>ImageNvim: Display image
    ImageNvim-->>User: Show inline
```

## Multiple Diagrams

You can have multiple diagrams in one file:

```mermaid
graph LR
    A[Phase 2] --> B[Markdown]
    A --> C[Visual Selection]
    A --> D[CSS Styling]
```

## Testing Visual Selection

Select the lines below and use `<leader>mr` to render just the selection:

graph TD
    VS[Visual Selection] --> R[Render]
    R --> P[Preview]

## Non-Mermaid Code Blocks

This shouldn't be processed:

```javascript
// This is JavaScript, not mermaid
function hello() {
    console.log("Hello, world!");
}
```

## Class Diagram with Custom Styling

When using custom CSS, this should look different:

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound()
    }
    class Dog {
        +String breed
        +bark()
    }
    class Cat {
        +boolean hasClaws
        +meow()
    }
    Animal <|-- Dog
    Animal <|-- Cat
```