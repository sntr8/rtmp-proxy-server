/**
 * Simple Carousel - Vanilla JavaScript Implementation
 */
(function() {
    'use strict';

    function Carousel(element, options) {
        this.element = element;
        this.slides = element.querySelectorAll('.carousel-slide');
        this.currentIndex = 0;
        this.intervalId = null;

        // Default options
        this.options = {
            speed: 5000,           // Fade transition duration (ms)
            autoplaySpeed: 15000,  // Time between slides (ms)
            autoplay: true,
            infinite: true
        };

        // Merge user options
        if (options) {
            for (var key in options) {
                if (options.hasOwnProperty(key)) {
                    this.options[key] = options[key];
                }
            }
        }

        this.init();
    }

    Carousel.prototype.init = function() {
        if (this.slides.length === 0) {
            return;
        }

        // Set initial state
        for (var i = 0; i < this.slides.length; i++) {
            this.slides[i].style.opacity = '0';
            this.slides[i].style.transition = 'opacity ' + (this.options.speed / 1000) + 's linear';
            this.slides[i].style.position = 'absolute';
            this.slides[i].style.top = '0';
            this.slides[i].style.left = '0';
            this.slides[i].style.width = '100%';
            this.slides[i].style.height = '100%';
        }

        // Show first slide
        this.slides[0].style.opacity = '1';
        this.currentIndex = 0;

        // Start autoplay
        if (this.options.autoplay) {
            this.startAutoplay();
        }
    };

    Carousel.prototype.goToSlide = function(index) {
        // Hide current slide
        this.slides[this.currentIndex].style.opacity = '0';

        // Show next slide
        this.currentIndex = index;
        this.slides[this.currentIndex].style.opacity = '1';
    };

    Carousel.prototype.next = function() {
        var nextIndex = this.currentIndex + 1;

        if (nextIndex >= this.slides.length) {
            if (this.options.infinite) {
                nextIndex = 0;
            } else {
                return;
            }
        }

        this.goToSlide(nextIndex);
    };

    Carousel.prototype.startAutoplay = function() {
        var self = this;
        this.intervalId = setInterval(function() {
            self.next();
        }, this.options.autoplaySpeed);
    };

    Carousel.prototype.stopAutoplay = function() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    };

    // Initialize carousel when DOM is ready
    function initCarousels() {
        var carousels = document.querySelectorAll('.carousel');
        for (var i = 0; i < carousels.length; i++) {
            new Carousel(carousels[i], {
                speed: 5000,
                autoplaySpeed: 15000,
                autoplay: true,
                infinite: true
            });
        }
    }

    // DOM ready check
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initCarousels);
    } else {
        initCarousels();
    }
})();
