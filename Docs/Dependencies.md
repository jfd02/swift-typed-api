# Dependencies

By default, CreateAPI uses [TypedAPI](https://github.com/0xff8c00/swift-typed-api) for the generated request/runtime layer. If you are generating a package, this dependency is set up for you automatically, but if you are generating for an existing module, you will need to manage dependencies yourself.

Below is a table that describes dependencies that CreateAPI generated code might need to use:

Dependency|Minimum Version|Required When?
---|---|---
[TypedAPI](https://github.com/0xff8c00/swift-typed-api)|0.3.0|Generating Paths*
[URLQueryEncoder](https://github.com/CreateAPI/URLQueryEncoder)|0.0.2|Generating paths with query parameters
[HTTPHeaders](https://github.com/CreateAPI/HTTPHeaders)|0.1.0|[`includeResponseHeaders`](./ConfigOptions.md#pathsincluderesponseheaders) is set to `true` (the default)
[NaiveDate](https://github.com/CreateAPI/NaiveDate)|1.0.0|[`useNaiveDate`](./ConfigOptions.md#usenaivedate) is set to `true` (the default)


> **Note**: _*If you are already using a different API client and don't want to depend on TypedAPI, check out the [Advanced Setup](./AdvancedSetup.md#using-a-different-api-client) documentation._
