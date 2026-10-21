Install the .NET 10 SDK from
https://dotnet.microsoft.com/en-us/download/dotnet/10.0 - the compiler
runs on it, and a ghūl project is an ordinary .NET SDK project.

1. Clone https://github.com/ghul-lang/ghul-repository-template, or
   the scratchpad or examples repository, for a project to start
   from. The compiler is pinned in each as a local .NET tool, so
   `dotnet tool restore` fetches the right version with the code.
2. Put the program below in a .ghul file in that project.
3. Run `dotnet run`.

The output appears in the terminal you ran it from. `dotnet build`,
`dotnet test`, `dotnet pack` and the rest all work as they would on a
C# project.

For an editor, Visual Studio Code (https://code.visualstudio.com) with
the ghūl extension
(https://marketplace.visualstudio.com/items?itemName=degory.ghul) gives
errors as you type, completion, hover, go to definition, rename and
formatting. Any editor that installs VS Code extensions gets the same;
others can drive the language server directly, which
https://ghul.dev/tooling.html covers.
