<%= $cmdletHelp.Synopsis %>

<%= $cmdletHelp.Description.Text %>

**Examples:**
<% foreach ($example in $cmdletHelp.Examples.example) { %>

``````PowerShell
<%= $example.code %>
``````

<%= $example.remarks.Text %>
<% } %>
