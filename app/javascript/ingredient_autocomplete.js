// Ingredient autocomplete functionality
(function() {
  let timeoutId = null;
  let selectedIndex = -1;
  let inputHandler = null;
  let blurHandler = null;
  let keydownHandler = null;
  let clickHandler = null;

  function initAutocomplete() {
    const input = document.getElementById('ingredient-name-input');
    const suggestions = document.getElementById('ingredient-suggestions');
    
    if (!input || !suggestions) return;

    const searchUrl = input.dataset.searchUrl;
    if (!searchUrl) return;

    // Remove old event listeners if they exist (using stored handlers)
    if (input.dataset.autocompleteInitialized === 'true') {
      if (inputHandler) {
        input.removeEventListener('input', inputHandler);
      }
      if (blurHandler) {
        input.removeEventListener('blur', blurHandler);
      }
      if (keydownHandler) {
        input.removeEventListener('keydown', keydownHandler);
      }
      if (clickHandler) {
        document.removeEventListener('click', clickHandler);
      }
      // Clear handlers to allow new ones to be created
      inputHandler = null;
      blurHandler = null;
      keydownHandler = null;
      clickHandler = null;
    }

    // Reset state
    timeoutId = null;
    selectedIndex = -1;

    function hideSuggestions() {
      suggestions.classList.add('hidden');
      selectedIndex = -1;
    }

    function showSuggestions(items) {
      if (items.length === 0) {
        hideSuggestions();
        return;
      }

      suggestions.innerHTML = items.map((item, index) =>
        `<div class="suggestion-item" data-index="${index}" data-name="${item.name}">${item.name}</div>`
      ).join('');

      suggestions.classList.remove('hidden');

      // Add click handlers
      suggestions.querySelectorAll('.suggestion-item').forEach(item => {
        item.addEventListener('click', function() {
          input.value = this.dataset.name;
          hideSuggestions();
        });
      });
    }

    function searchIngredients(query) {
      if (query.length < 2) {
        hideSuggestions();
        return;
      }

      fetch(`${searchUrl}?q=${encodeURIComponent(query)}`)
        .then(response => response.json())
        .then(data => {
          showSuggestions(data);
        })
        .catch(() => {
          hideSuggestions();
        });
    }

    // Create handler functions and store references
    inputHandler = function(e) {
      clearTimeout(timeoutId);
      const query = e.target.value.trim();

      if (query.length < 2) {
        hideSuggestions();
        return;
      }

      timeoutId = setTimeout(() => {
        searchIngredients(query);
      }, 300);
    };

    blurHandler = function() {
      // Delay hiding to allow click on suggestion
      setTimeout(hideSuggestions, 200);
    };

    keydownHandler = function(e) {
      const items = suggestions.querySelectorAll('.suggestion-item');

      if (items.length === 0) return;

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedIndex = Math.min(selectedIndex + 1, items.length - 1);
        items[selectedIndex].classList.add('selected');
        if (selectedIndex > 0) {
          items[selectedIndex - 1].classList.remove('selected');
        }
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (selectedIndex > 0) {
          items[selectedIndex].classList.remove('selected');
          selectedIndex--;
          items[selectedIndex].classList.add('selected');
        }
      } else if (e.key === 'Enter' && selectedIndex >= 0) {
        e.preventDefault();
        input.value = items[selectedIndex].dataset.name;
        hideSuggestions();
      } else if (e.key === 'Escape') {
        hideSuggestions();
      }
    };

    clickHandler = function(e) {
      if (!input.contains(e.target) && !suggestions.contains(e.target)) {
        hideSuggestions();
      }
    };

    // Add event listeners
    input.addEventListener('input', inputHandler);
    input.addEventListener('blur', blurHandler);
    input.addEventListener('keydown', keydownHandler);
    document.addEventListener('click', clickHandler);

    // Mark as initialized
    input.dataset.autocompleteInitialized = 'true';
  }

  // Don't initialize on page load - wait for modal to open
  // This prevents attaching listeners when modal is hidden
  // The modal.js will call initAutocomplete when opening

  // Make function globally available
  window.initAutocomplete = initAutocomplete;
})();

