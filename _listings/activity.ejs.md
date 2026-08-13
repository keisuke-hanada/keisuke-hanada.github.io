<ul class="activity-list list">
<% for (const item of items) { %>
  <li class="activity-entry" <%= metadataAttrs(item) %>><span class="activity-period"><%- item.period %></span> <span class="listing-title"><%- item.title %></span><% if (item.details) { %><span class="activity-details">, <%- item.details %></span><% } %></li>
<% } %>
</ul>
