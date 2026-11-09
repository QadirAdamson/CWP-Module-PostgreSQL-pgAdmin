<script type="text/javascript">
$(document).ready(function() {
    // 1. Remove duplicate items if previously appended
    $("#mn-pgmanager-sub").remove();

    var pgSubItem = '<li id="mn-pgmanager-sub">'
        + '<a href="index.php?module=postgresql_pgadmin" style="font-weight:bold; color:#336791;">'
        + '<span class="icon16 icomoon-icon-database" style="color: #336791 !important; margin-right: 5px;"></span>'
        + '<span class="txt">PostgreSQL / pgAdmin</span>'
        + '</a>'
        + '</li>';

    // 2. Find SQL Services parent in sidebar and PREPEND
    var $sqlLi = null;
    var $sqlSub = null;

    $(".mainnav > ul > li").each(function() {
        var $a = $(this).children("a");
        var txt = $a.text().trim();
        if (txt.indexOf("SQL") !== -1 || txt.indexOf("Database") !== -1 || txt.indexOf("Veritabanı") !== -1) {
            $sqlLi = $(this);
            $sqlSub = $(this).find("ul.sub");
            return false;
        }
    });

    if ($sqlSub && $sqlSub.length) {
        $sqlSub.prepend(pgSubItem);
    } else if ($("#mn-12-sub").length) {
        $("#mn-12-sub").prepend(pgSubItem);
    }

    // 3. Highlight and keep SQL Services menu expanded when on postgresql_pgadmin module
    if (window.location.search.indexOf('module=postgresql_pgadmin') !== -1 || window.location.href.indexOf('module=postgresql_pgadmin') !== -1) {
        if ($sqlSub && $sqlSub.length) {
            $sqlSub.addClass("show").css("display", "block");
        }
        if ($sqlLi && $sqlLi.length) {
            $sqlLi.addClass("hasSub highlight-menu active-state");
            var $toggle = $sqlLi.children("a.hasUl, a.notExpand");
            if ($toggle.length) {
                $toggle.removeClass("notExpand").addClass("expand active-state");
            }
        }
        $("#mn-pgmanager-sub > a").addClass("active");
    }
});
</script>
