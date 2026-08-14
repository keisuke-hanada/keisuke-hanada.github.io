<div class="news-list list">
<% for (const item of items) { %>
<div class="news-entry" <%= metadataAttrs(item) %>><time class="listing-date" datetime="<%- item.date %>"><%- item.date %></time><% if (item.href) { %><a class="listing-title" href="<%- item.href %>"><%- item.title %></a><% } else { %><span class="listing-title"><%- item.title %></span><% } %></div>
<% } %>
</div>
