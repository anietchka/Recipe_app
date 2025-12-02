// Ingredient autocomplete functionality
(function() {
  function initAutocomplete() {
    const input = document.getElementById('ingredient-name-input');
    const suggestions = document.getElementById('ingredient-suggestions');
    
    if (!input || !suggestions) return;

    const searchUrl = input.dataset.searchUrl;
    if (!searchUrl) return;

    let timeoutId = null;
    let selectedIndex = -1;

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

    input.addEventListener('input', function(e) {
      clearTimeout(timeoutId);
      const query = e.target.value.trim();

      if (query.length < 2) {
        hideSuggestions();
        return;
      }

      timeoutId = setTimeout(() => {
        searchIngredients(query);
      }, 300);
    });

    input.addEventListener('blur', function() {
      // Delay hiding to allow click on suggestion
      setTimeout(hideSuggestions, 200);
    });

    input.addEventListener('keydown', function(e) {
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
    });

    // Hide suggestions when clicking outside
    document.addEventListener('click', function(e) {
      if (!input.contains(e.target) && !suggestions.contains(e.target)) {
        hideSuggestions();
      }
    });
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAutocomplete);
  } else {
    initAutocomplete();
  }
})();

