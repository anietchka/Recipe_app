import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autocomplete"
export default class extends Controller {
  static targets = ["input", "suggestions"]
  static values = {
    searchUrl: String,
    minLength: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.selectedIndex = -1
    this.timeoutId = null
  }

  disconnect() {
    this.clearTimeout()
  }

  search() {
    this.clearTimeout()
    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.hideSuggestions()
      return
    }

    this.timeoutId = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceValue)
  }

  performSearch(query) {
    // Fallback to default URL if searchUrlValue is not set
    const baseUrl = this.searchUrlValue || '/ingredients/search'
    const url = `${baseUrl}?q=${encodeURIComponent(query)}`
    
    fetch(url)
      .then(response => response.json())
      .then(data => {
        this.showSuggestions(data)
      })
      .catch(() => {
        this.hideSuggestions()
      })
  }

  showSuggestions(items) {
    if (items.length === 0) {
      this.hideSuggestions()
      return
    }

    this.suggestionsTarget.innerHTML = items.map((item, index) =>
      `<div class="suggestion-item" data-index="${index}" data-action="click->autocomplete#select" data-name="${item.name}">${item.name}</div>`
    ).join('')

    this.suggestionsTarget.classList.remove('hidden')
    this.selectedIndex = -1
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add('hidden')
    this.suggestionsTarget.innerHTML = ''
    this.selectedIndex = -1
  }

  select(event) {
    const name = event.currentTarget.dataset.name
    this.inputTarget.value = name
    this.hideSuggestions()
    this.inputTarget.focus()
  }

  handleKeydown(event) {
    const items = this.suggestionsTarget.querySelectorAll('.suggestion-item')

    if (items.length === 0) return

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.updateSelection(items)
        break
      case 'ArrowUp':
        event.preventDefault()
        if (this.selectedIndex > 0) {
          this.selectedIndex--
          this.updateSelection(items)
        }
        break
      case 'Enter':
        if (this.selectedIndex >= 0) {
          event.preventDefault()
          items[this.selectedIndex].click()
        }
        break
      case 'Escape':
        this.hideSuggestions()
        break
    }
  }

  updateSelection(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('selected')
      } else {
        item.classList.remove('selected')
      }
    })
  }

  handleBlur() {
    // Delay hiding to allow click on suggestion
    setTimeout(() => {
      // Check if focus moved to a suggestion item
      const activeElement = document.activeElement
      const isClickingSuggestion = this.suggestionsTarget.contains(activeElement)
      
      if (!isClickingSuggestion) {
        this.hideSuggestions()
      }
    }, 200)
  }

  handleClickOutside(event) {
    // Don't hide if clicking inside the autocomplete element (input or suggestions)
    const clickedInside = this.element.contains(event.target) || 
                         this.suggestionsTarget.contains(event.target)
    
    if (!clickedInside) {
      this.hideSuggestions()
    }
  }

  clearTimeout() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }
}

