/**
 * @preserve Setup the basis for the responsive menu.
 * @author Mikael Roos <mos@dbwebb.se>
 * @see {@link https://github.com/mosbth/responsive-menu}
 */
(function() {
    "use strict";

    // Get the items needed for the menu to work.
    var menuButton = document.getElementById("rm-menu-button");
    var menu = document.querySelector(".rm-default");
    var submenus = document.getElementsByClassName("rm-submenu");

    // To support WordPress submenus
    var submenuswp = document.getElementsByClassName("sub-menu");



    /**
     * Show submenu where ever a li item holds a submenu. Used as callback
     * for li click events but only valid for the mobile version. The desktop
     * version uses hover instead och click events.
     */
    var showSubmenu = function() {
        //console.log("Show submenu");

        if (this.parentNode.classList.contains("rm-desktop")) {
            //console.log("Cancel show submenu");
            return;
        }

        this.classList.toggle("rm-submenu-open");
        this.querySelector("ul").classList.toggle("rm-show-submenu");
    };



    /**
     * Add eventlisteners for each li holding a submenu
     */
    Array.prototype.filter.call(submenus, function(element) {
        element.addEventListener("click", showSubmenu);
        //console.log("found submenu");
    });

    // To support WordPress menus
    Array.prototype.filter.call(submenuswp, function(element) {
        element.parentNode.addEventListener("click", showSubmenu);
        //console.log("found submenuwp");
    });



    /**
     * Show the menu when clicking on the closed (mobile) menu button.
     */
    menuButton.addEventListener("click", function(event) {

        var style = window.getComputedStyle(menu);

        //console.log("Click: " + style.display);

        if (style.display === "none") {
            // Display the menu
            menu.classList.toggle("rm-mobile");
            menu.classList.toggle("rm-desktop");
            menuButton.classList.toggle("rm-clicked");
            menu.style.display = "block";
        } else {
            // Hide the menu
            menu.style.display = "none";
            menu.classList.toggle("rm-mobile");
            menu.classList.toggle("rm-desktop");
            menuButton.classList.toggle("rm-clicked");
        }

        event.preventDefault();
        event.stopPropagation();
    });



    /**
     *
     */
    var clearMenu = function (event) {
        //console.log("Clear menu");
        menu.style.display = "";
        menu.classList.remove("rm-mobile");
        menu.classList.add("rm-desktop");
        menuButton.classList.remove("rm-clicked");
        event.preventDefault();
    };

    window.addEventListener("resize", clearMenu);
    //document.addEventListener("click", clearMenu);

})();
