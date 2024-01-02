<h1>A PDF Page Turner for Reapers WebRC </h1>

<h2>What pdfPageTurner does:</h2>

1. Display a selected pdf in a browser (Firefox), using Reapers WebRC
2. Switches to a certain page of the pdf, according to markers set in reaper with a special naming (default <#S>+<number>, for exmpaple <#S5> for page 5, <#S17> for page 17) 
3. Defautl marker tag (<#S>) can be set to any individual tag
4. Page Offset can be set, if pdf content doesn't start on first page
5. File path, marker tag and page offset are store in the Reaper project.

<h2> Known issues</h2>

1. Only works with Firefox so far
2. PDF sometimes keep refreshing / reloading.
3. Files have to be placed in the servers path ../reaper_www_root
4. Due to the limitation that files have to stay in the server path, files can not be selected from mobile devices.
  You will have to load the file from the machine Reaper is running, but than you can display and edit all settings frome mobile devices.
