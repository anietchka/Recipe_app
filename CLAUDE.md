# Recipe App

## Project context

This is a Ruby on Rails case-study application.

The main product goal is to help users answer:

"Given what I currently have in my pantry, what can I cook?"

Users maintain a pantry, browse recipes ranked according to the ingredients they have, see which ingredients are missing, and can mark a recipe as cooked.

When a recipe is cooked, tracked pantry quantities are updated accordingly.

## Engineering principles

This project deliberately favors simplicity, readability, and explicit business rules over premature optimization or abstraction.

When modifying the code:

- Prefer the simplest implementation that satisfies the business rule.
- Do not introduce abstractions without a concrete need.
- Prefer deleting unnecessary complexity over moving it elsewhere.
- Keep controllers thin.
- Use service objects for meaningful business operations, not for trivial logic.
- Avoid premature performance optimization.
- Keep business terminology consistent across the application.
- Add or update tests when changing business behavior.
- Do not make unrelated refactors while implementing a scoped change.

## Current V2 business rules

### Quantities

- Quantities should use a single numeric value.
- Fractions are a presentation concern, not a separate business value.
- A missing quantity stays `nil`; never implicitly convert it to `1`.
- A pantry item may have no tracked quantity. This means the user has the ingredient but does not track its exact stock.

### Recipe matching

An ingredient is considered available when:

- the ingredient exists in the user's pantry, AND
- if its pantry quantity is tracked, the available quantity is sufficient.

If the pantry quantity is not tracked, ingredient presence is enough.

An ingredient with a tracked but insufficient quantity is considered missing.

The same definition of matched/missing should be used consistently throughout the application.

### Units

Only compatible units should be converted.

Examples:
- g <-> kg
- ml <-> l

Do not attempt weight-to-volume conversions such as grams to cups, because these would require ingredient-specific density information.

If quantities cannot be reliably compared because units are incompatible, the application must not assume that the available quantity is sufficient.

### Cooking

Missing ingredients do not prevent a user from marking a recipe as cooked.

When cooking:
- only tracked quantities are decremented;
- untracked pantry quantities remain unchanged;
- quantities must never become negative;
- pantry updates and cooking history must be performed atomically in a database transaction.

## Scope discipline

Make changes incrementally.

When asked to work on one part of the application:
- do not redesign unrelated parts;
- explain any broader issue you notice instead of fixing it automatically;
- do not add speculative features.

This is especially important because every architectural decision in this project must remain easy to explain and justify during a technical interview.