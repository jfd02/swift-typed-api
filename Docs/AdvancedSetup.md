# Advanced Setup

Looking for examples that push CreateAPI to it's limits? Well look no further.

<!-- Be sure to update this TOC when adding new sections! -->
- [Using a different API Client](#using-a-different-api-client)

## Using a different API Client

While using [TypedAPI](https://github.com/0xff8c00/swift-typed-api) is the easiest way to get started with CreateAPI, you might want to integrate CreateAPI with a different client instead.

To do this, there are two important steps that need following:

1. Exclude the `TypedAPI` import in the generated paths
2. Write a matching `Request` type

### Exclude the `TypedAPI` import

Using the [`paths.imports`](./ConfigOptions.md#pathsimports) option, override the default value (`["TypedAPI"]`) to omit the import:

**.create-api.yaml**
```yaml
paths:
  # Ensure that TypedAPI is not imported in generated source files
  imports: []
```

### Write a matching `Request` type

The generated code needs to initialize a type called `Request` to define all of the path parameters and response type. When importing `TypedAPI`, `Request` is already available to the generated code, but after removing the import this will no longer be the case.

You should either add a new `Request` type to the module of the generated code, or import one from a different module (be sure to update `paths.imports` if so). The type should be compatible with [`TypedAPI.Request`](https://github.com/0xff8c00/swift-typed-api):

```swift
struct Request<Success, Failure: Error> {
    init(
        path: String,
        method: String = "GET",
        query: [(String, String?)]? = nil,
        body: Encodable? = nil,
        headers: [String: String]? = nil,
        id: String? = nil
    ) {
        // Store the generated request data here
    }
}
```

The generated Paths will provide configured instances of this `Request` type that you can then pass into your own API client instead.
