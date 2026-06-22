<img width="80px" src="https://user-images.githubusercontent.com/1567433/146774765-4671c989-62c3-4418-8bdb-2773d7a26067.png">

# Create API

Delightful code generation for OpenAPI specs for Swift written in Swift.

- **Fast**: processes specs with 100K lines of YAML in less than a second
- **Smart**: generates Swift code that looks like it's carefully written by hand
- **Reliable**: tested on 1KK lines of publicly available OpenAPI specs producing correct code every time
- **Customizable**: offers a ton of customization options

> Powered by [OpenAPIKit](https://github.com/mattpolzin/OpenAPIKit)

## How this differs from CreateAPI

This is a fork of [CreateAPI](https://github.com/CreateAPI/CreateAPI). It keeps CreateAPI's OpenAPI-to-Swift generator and swaps the runtime: generated clients depend on the bundled **`TypedAPI`** module instead of [Get](https://github.com/kean/Get). The headline difference is **typed errors**:

- Each operation returns `Request<Success, Failure>`, where `Failure` is a generated enum conforming to `RequestError` — one case per documented response status code, plus an `unhandled` catch-all.
- `APIClient.send(_:)` uses Swift 6 **typed throws** (`async throws(E)`), so the concrete error type is known at the call site and you can exhaustively `catch` individual API errors.
- Every error exposes `statusCode` and `underlyingError`, so even a catch-all handler can log the HTTP status and the underlying transport/decoding failure.

See the [Example](#example) below for what this looks like in practice, and the [CHANGELOG](./CHANGELOG.md) for the full list of fork changes.

## Installation

### Build from source

```bash
$ git clone https://github.com/jfd02/swift-typed-api.git
$ cd swift-typed-api
$ make install   # builds and installs the `create-api` binary into /usr/local/bin
```

You can also run the generator straight from a clone without installing it:

```bash
$ swift run create-api generate <schema> --output <output-dir>
```

### [Mint](https://github.com/yonaskolb/Mint)

```bash
$ mint install jfd02/swift-typed-api
```

### Swift Package Plugins

- [Creating a Swift Package Plugin](./Docs/SwiftPackagePlugins.md)

> [!NOTE]
> This is a fork. `brew install create-api` and `mint install CreateAPI/CreateAPI` install the **upstream** CreateAPI, which uses [Get](https://github.com/kean/Get) rather than `TypedAPI` and has no typed errors. Use the commands above to install this fork.

## Getting Started

You'll need an [OpenAPI schema](https://swagger.io/specification/) using OpenAPI 3.1.x for your API. If your schema has external references, you might also need to bundle it beforehand.

If you have never used CreateAPI before, be sure to check out our tutorial: [Generating an API with CreateAPI](./Docs/Tutorial.md)

CreateAPI can generate complete Swift Package bundles but can also generate individual components to integrate into an existing project. Either way, you'll want to use the `generate` command:

<details>
<summary><b><code>$ create-api generate --help</code></b></summary>

```
USAGE: create-api generate <input> [--output <output>] [--config <config>] [--config-option <config-option> ...] [--verbose] [--strict] [--allow-errors] [--clean] [--watch] [--single-threaded] [--measure]

ARGUMENTS:
  <input>                 The path to the OpenAPI spec in either JSON or YAML format

OPTIONS:
  --output <output>       The directory where generated outputs are written (default: CreateAPI)
  --config <config>       The path to the generator configuration. (default: .create-api.yaml)
  --config-option <config-option>
                          Option overrides to be applied when generating.

        In scenarios where you need to customize behaviour when invoking the generator, use this option to
        specify individual overrides. For example:

        --config-option "module=MyAPIKit"
        --config-option "entities.filenameTemplate=%0DTO.swift"

        You can specify multiple --config-option arguments and the value of each one must match the
        'keyPath=value' format above where keyPath is a dot separated path to the option and value is the
        yaml/json representation of the option.

  -v, --verbose           Enables verbose log messages
  --strict                Treats warnings as errors and fails generation
  --allow-errors          Ignore errors that occur during generation and continue if possible
  -c, --clean             Removes the output directory before writing generated outputs
  --watch                 Monitor changes to both the spec and the configuration file and automatically
                          regenerate outputs
  --single-threaded       Disables parallelization
  --measure               Measure performance of individual operations and log timings
  --version               Show the version.
  -h, --help              Show help information.
```

</details>

To try CreateAPI out, run the following commands:

```bash
$ curl "https://petstore3.swagger.io/api/v3/openapi.json" > schema.json
$ create-api generate schema.json --config-option module=PetstoreKit --output PetstoreKit
$ cd PetstoreKit
$ swift build
```

There you have it, a compiling Swift Package ready to be integrated with your other Swift projects!

Generated packages include a dependency on `TypedAPI`, which provides the runtime `APIClient` and typed `Request<Success, Failure>` support used by the generated paths.

For more information about using CreateAPI, check out the [Documentation](./Docs/).

## Example

Given a small OpenAPI 3.1 schema like this:

```yaml
openapi: 3.1.0
info:
  title: Petstore
  version: 1.0.0
paths:
  /pets:
    post:
      operationId: createPet
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/NewPet"
      responses:
        "201":
          description: Created pet
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Pet"
        "409":
          description: Pet already exists
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "422":
          description: Validation failed
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
components:
  schemas:
    NewPet:
      type: object
      required: [name]
      properties:
        name:
          type: string
    Pet:
      type: object
      required: [id, name]
      properties:
        id:
          type: integer
        name:
          type: string
    ErrorResponse:
      type: object
      required: [message]
      properties:
        message:
          type: string
```

CreateAPI generates Swift that uses `TypedAPI` like this:

```swift
import Foundation
import TypedAPI

public enum Paths {
    public static var pets: Pets {
        Pets(path: "/pets")
    }

    public struct Pets {
        public let path: String

        public func post(_ body: PostRequest) -> Request<PetstoreKit.Pet, PostError> {
            Request(path: path, method: "POST", body: body, id: "createPet")
        }

        public enum PostError: RequestError {
            case conflict(PetstoreKit.ErrorResponse)
            case unprocessableEntity(PetstoreKit.ErrorResponse)
            case unhandled(any Swift.Error)
        }

        public struct PostRequest: Codable {
            public var name: String
        }
    }
}

public struct Pet: Codable {
    public var id: Int
    public var name: String
}
```

That lets you handle real API errors directly in Swift:

```swift
import Foundation
import PetstoreKit
import TypedAPI

let client = APIClient(baseURL: URL(string: "https://example.com"))
let request = Paths.pets.post(.init(name: "Fido"))

do {
    let pet = try await client.send(request).value
    print("Created pet:", pet)
} catch Paths.Pets.PostError.conflict(let errorResponse) {
    print("A pet with that name already exists:", errorResponse.message)
} catch Paths.Pets.PostError.unprocessableEntity(let errorResponse) {
    print("The API rejected the payload:", errorResponse.message)
} catch Paths.Pets.PostError.unhandled(let error) {
    print("Transport or decoding error: \(error)")
}
```

## Acknowledgements

This implementation builds on ideas and prior work from:

- [CreateAPI](https://github.com/CreateAPI/CreateAPI) for the OpenAPI-to-Swift generator foundation.
- [Get](https://github.com/kean/Get) by Alexander Grebenyuk for the API client/runtime design that `TypedAPI` adapts.

## Contributing

We always welcome contributions from the community via Issues and Pull Requests. Please be sure to read over the [contributing guidelines](./CONTRIBUTING.md) for more information.
