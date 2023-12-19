A playgound with a function `async<T>(timeout: TimeInterval, work: @escaping() async -> T) async throws -> T`, which provides a way to call async functions with a timeout.

Use it like this:

```swift
func someAsyncFunction() async -> SomeType {
  ...
  await something
  ...
  return doubelValue
}
...
do {
  let result = try await async(timeout: 1, work: someAsyncFunction) // tries to receive result from
                                                                // someAsyncFunction within 1 second
  ...                          
} catch let asyncError as AsyncError {
  // will come here, when execution takes longer than one second
} catch {
  // will come here, when other errors occur unexpectetly
}   
```
For other / more complicated cases with async functions that throw or take parameters etc., checkout test code in playground.
