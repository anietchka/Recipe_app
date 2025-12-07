// Modal management for pantry items form
(function() {
  function resetAndCloseModal() {
    const modal = document.getElementById('add-form-modal');
    const form = document.getElementById('pantry-item-form');
    const suggestions = document.getElementById('ingredient-suggestions');

    if (form) {
      form.reset();
    }

    if (suggestions) {
      suggestions.classList.add('hidden');
      suggestions.innerHTML = '';
    }

    if (modal) {
      modal.classList.add('hidden');
    }
  }

  function openModal() {
    const modal = document.getElementById('add-form-modal');
    const input = document.getElementById('ingredient-name-input');
    
    if (modal) {
      modal.classList.remove('hidden');
      
      // Focus on ingredient input after modal is shown
      // Stimulus controller is already connected (connects on page load)
      if (input) {
        setTimeout(() => {
          input.focus();
        }, 200);
      }
    }
  }

  function initFormSubmit() {
    const form = document.getElementById('pantry-item-form');
    if (!form) return;

    // Handle Enter key submission
    form.addEventListener('keydown', function(e) {
      // Only submit if Enter is pressed and not in a textarea or if suggestions are not visible
      if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
        const suggestions = document.getElementById('ingredient-suggestions');
        const suggestionsVisible = suggestions && !suggestions.classList.contains('hidden');
        
        // Don't submit if suggestions are visible (user might be selecting)
        if (!suggestionsVisible) {
          // Check if form is valid
          if (form.checkValidity()) {
            e.preventDefault();
            form.submit();
          }
        }
      }
    });
  }

  // Initialize form submit handler when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFormSubmit);
  } else {
    initFormSubmit();
  }

  function openModalWithIngredient(ingredientName) {
    const modal = document.getElementById('add-form-modal');
    const input = document.getElementById('ingredient-name-input');
    
    if (modal && input) {
      // Reset form first
      const form = document.getElementById('pantry-item-form');
      if (form) {
        form.reset();
      }
      
      // Set ingredient name
      input.value = ingredientName;
      
      // Open modal
      modal.classList.remove('hidden');
      
      // Focus on ingredient input after modal is shown
      // Stimulus controller is already connected (connects on page load)
      setTimeout(() => {
        input.focus();
        // Move cursor to end
        input.setSelectionRange(input.value.length, input.value.length);
      }, 200);
    }
  }

  // Make functions globally available
  window.resetAndCloseModal = resetAndCloseModal;
  window.openModal = openModal;
  window.openModalWithIngredient = openModalWithIngredient;
})();

