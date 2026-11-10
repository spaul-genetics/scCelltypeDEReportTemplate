// Interactive behavior for report_template.qmd.
// Expects TEMPLATE_DATA containing cluster records and embedded image URIs.
(function () {
  "use strict";
  const D = TEMPLATE_DATA;
  const C = D.clusters;
  const labels = {
    agree: "Supported annotation",
    minor: "Supported with qualification",
    excl: "QC-excluded"
  };
  const box = document.getElementById("umapbox");
  const cardBox = document.getElementById("cluster-cards");
  const support = document.getElementById("support-panel");
  const deFigures = document.getElementById("de-figures");
  const deCards = document.getElementById("de-cards");
  const zoom = document.getElementById("zoom");
  let selected = null;
  let filter = "all";

  const umaps = D.umaps || [
    {title: "Clusters", uri: D.umap, interactive_clusters: true}
  ];
  const umapTabs = document.getElementById("umap-tabs");

  function showUmap(index) {
    document.getElementById("umapimg").src = umaps[index].uri;
    umapTabs.querySelectorAll("button").forEach(function (button, i) {
      button.classList.toggle("on", i === index);
    });
    document.querySelectorAll(".hotspot").forEach(function (hotspot) {
      hotspot.style.display = umaps[index].interactive_clusters ? "" : "none";
    });
  }

  umaps.forEach(function (umap, index) {
    const button = document.createElement("button");
    button.textContent = umap.title;
    button.onclick = function () { showUmap(index); };
    umapTabs.appendChild(button);
  });
  showUmap(0);
  document.getElementById("callout-slot").innerHTML = D.callouts_html || "";

  function zoomable(img) {
    img.onclick = function () {
      document.getElementById("zoom-image").src = img.src;
      zoom.style.display = "flex";
    };
  }
  zoom.onclick = function () { zoom.style.display = "none"; };

  function supportPanel(cluster, tabIndex) {
    const tab = tabIndex || 0;
    const fig = cluster.figs[tab];
    support.innerHTML =
      '<div class="panel-head"><b>Cluster ' + cluster.id + ': ' + cluster.label +
      '</b><span>' + fig.title + '</span></div>' +
      '<div class="tab-row">' +
      cluster.figs.map(function (x, i) {
        return '<button class="' + (i === tab ? 'on' : '') +
          '" data-support-tab="' + i + '">' + x.title + '</button>';
      }).join("") +
      '</div><div class="figure-wrap"><img src="' + fig.uri + '" alt="' + fig.title + '">' +
      '<p class="caption"><b>Figure caption.</b> ' + fig.caption + '</p></div>';
    support.querySelectorAll("[data-support-tab]").forEach(function (button) {
      button.onclick = function () { supportPanel(cluster, Number(button.dataset.supportTab)); };
    });
    zoomable(support.querySelector("img"));
  }

  function dePanel(cluster, tabIndex) {
    const tab = tabIndex || 0;
    const fig = cluster.de_figs[tab];
    deFigures.innerHTML =
      '<div class="panel-head"><b>Cluster ' + cluster.id + ': ' + cluster.label +
      '</b><span>' + fig.title + '</span></div>' +
      '<div class="tab-row de-tabs">' +
      cluster.de_figs.map(function (x, i) {
        return '<button class="' + (i === tab ? 'on' : '') +
          '" data-de-tab="' + i + '">' + x.title + '</button>';
      }).join("") +
      '</div><div class="figure-wrap"><img src="' + fig.uri + '" alt="' + fig.title + '">' +
      '<p class="caption"><b>Figure caption.</b> ' + fig.caption + '</p></div>';
    deFigures.querySelectorAll("[data-de-tab]").forEach(function (button) {
      button.onclick = function () { dePanel(cluster, Number(button.dataset.deTab)); };
    });
    zoomable(deFigures.querySelector("img"));
  }

  function selectCluster(id, scrollToCard) {
    selected = String(id);
    C.forEach(function (cluster) {
      const active = String(cluster.id) === selected;
      document.getElementById("hot-" + cluster.id).classList.toggle("selected", active);
      document.getElementById("card-" + cluster.id).classList.toggle("selected", active);
      document.getElementById("card-" + cluster.id).classList.toggle("open", active);
      document.getElementById("de-card-" + cluster.id).classList.toggle("selected", active);
    });
    const cluster = C.find(function (x) { return String(x.id) === selected; });
    supportPanel(cluster, 0);
    dePanel(cluster, 0);
    if (scrollToCard) {
      document.getElementById("card-" + id).scrollIntoView({behavior: "smooth", block: "center"});
    }
  }

  C.forEach(function (cluster) {
    const hot = document.createElement("button");
    hot.id = "hot-" + cluster.id;
    hot.className = "hotspot " + cluster.status;
    hot.textContent = cluster.id;
    hot.style.left = (100 * cluster.pos_x) + "%";
    hot.style.top = (100 * cluster.pos_y) + "%";
    hot.onclick = function () { selectCluster(cluster.id, true); };
    box.appendChild(hot);

    const card = document.createElement("article");
    card.id = "card-" + cluster.id;
    card.className = "cluster-card " + cluster.status;
    card.innerHTML =
      '<div class="card-head"><span class="cluster-number">' + cluster.id + '</span>' +
      '<span class="cluster-name">' + cluster.label +
      '<small>n=' + Number(cluster.cells).toLocaleString() + ' synthetic cells</small></span>' +
      '<span class="status-tag ' + cluster.status + '">' + labels[cluster.status] + '</span></div>' +
      '<div class="card-body"><h4>Evidence</h4><p>' + cluster.evidence + '</p>' +
      '<h4>Interpretation</h4><p>' + cluster.assessment + '</p>' +
      '<div class="recommendation"><b>Recommended annotation:</b> ' + cluster.suggestion + '</div>' +
      '<div class="meta">Supporting analyses: ' + cluster.pages + '</div></div>';
    card.querySelector(".card-head").onclick = function () { selectCluster(cluster.id, false); };
    cardBox.appendChild(card);

    const deCard = document.createElement("article");
    deCard.id = "de-card-" + cluster.id;
    deCard.className = "de-card";
    deCard.innerHTML =
      '<button data-de-cluster="' + cluster.id + '"><b>Cluster ' + cluster.id +
      '</b><span>' + cluster.label + '</span></button>' +
      '<div class="de-card-body"><h4>DE interpretation</h4><p>' + cluster.de_interpretation +
      '</p><h4>Biological qualification</h4><p>' + cluster.biological_qualification + '</p></div>';
    deCard.querySelector("button").onclick = function () { selectCluster(cluster.id, false); };
    deCards.appendChild(deCard);
  });

  const filterBox = document.getElementById("filters");
  [["all", "All"], ["agree", "Supported"], ["minor", "Qualified"], ["excl", "QC-excluded"]]
    .forEach(function (item) {
      const button = document.createElement("button");
      button.dataset.filter = item[0];
      button.textContent = item[1];
      button.onclick = function () {
        filter = item[0];
        document.querySelectorAll("#filters button").forEach(function (x) {
          x.classList.toggle("on", x === button);
        });
        C.forEach(function (cluster) {
          const show = filter === "all" || cluster.status === filter;
          document.getElementById("card-" + cluster.id).style.display = show ? "" : "none";
          document.getElementById("hot-" + cluster.id).classList.toggle("dimmed", !show);
        });
      };
      filterBox.appendChild(button);
    });
  filterBox.querySelector("button").click();

  const count = function (status) { return C.filter(function (x) { return x.status === status; }).length; };
  const total = C.reduce(function (sum, x) { return sum + Number(x.cells); }, 0);
  document.getElementById("summary-box").innerHTML =
    '<b>At a glance:</b> ' + count("agree") + ' supported clusters, ' +
    count("minor") + ' qualified clusters, and ' + count("excl") +
    ' QC-excluded cluster. Total: ' + total.toLocaleString() +
    ' synthetic cells.<div class="interpretive-limit"><b>Interpretive limit:</b> ' +
    D.interpretive_limit + '</div>';

  selectCluster(C[0].id, false);
})();
