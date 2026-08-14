<div class="research-list list">
<% for (const item of items) { %>
<% if (templateParams.collapsible) { %>
<details class="research-entry" id="<%- item.id %>" <%= metadataAttrs(item) %>>
  <summary><span class="listing-title">[<%- item['display-number'] %>] <%= item['citation-html'] %> <%= item['links-html'] || '' %></span></summary>
  <% if (item['description-html']) { %><div class="research-description"><%= item['description-html'] %></div><% } %>
</details>
<% } else { %>
<div class="research-entry research-entry-plain" id="<%- item.id %>" <%= metadataAttrs(item) %>>
  <span class="listing-title">[<%- item['display-number'] %>] <%= item['citation-html'] %> <%= item['links-html'] || '' %></span>
  <% if (item['description-html']) { %><div class="research-description"><%= item['description-html'] %></div><% } %>
</div>
<% } %>
<% } %>
</div>
