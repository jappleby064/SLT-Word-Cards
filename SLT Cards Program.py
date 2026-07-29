import csv
import os
import sys
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QLineEdit, QPushButton, QListWidget, 
                             QGroupBox, QGridLayout, QMessageBox, QDialog,
                             QListWidgetItem, QScrollArea)
from PyQt6.QtPrintSupport import QPrinter, QPrintPreviewDialog
from PyQt6.QtGui import QPixmap, QPainter, QPen, QColor, QPageLayout, QPageSize
from PyQt6.QtCore import Qt, QRectF, QSizeF
from PIL import Image

#all info stored in csv file

cards = []

def format_images(): # Cycle through unformatted folder, convert PNG to JPEG if needed, scale to 500x500, save to images folder
    unformatted_folder = 'unformatted'
    images_folder = 'images'
    
    # Create images folder if it doesn't exist
    os.makedirs(images_folder, exist_ok=True)
    
    # Check if directory exists
    if not os.path.exists(unformatted_folder):
        return

    # Cycle through all files in unformatted folder
    for filename in os.listdir(unformatted_folder):
        file_path = os.path.join(unformatted_folder, filename)
        
        # Skip if not a file
        if not os.path.isfile(file_path):
            continue
        
        try:
            # Open image
            img = Image.open(file_path)
            
            # Convert RGBA to RGB with white background if necessary
            if img.mode == 'RGBA':
                # Create white background
                background = Image.new('RGB', img.size, (255, 255, 255))
                background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
                img = background
            elif img.mode != 'RGB':
                img = img.convert('RGB')
            
            # Maintain aspect ratio and create 500x500 image with white padding
            img.thumbnail((500, 500), Image.Resampling.LANCZOS)
            
            # Create new 500x500 white image
            final_img = Image.new('RGB', (500, 500), (255, 255, 255))
            
            # Calculate position to center the image
            x = (500 - img.width) // 2
            y = (500 - img.height) // 2
            final_img.paste(img, (x, y))
            
            # Get filename without extension and save as JPEG
            name_without_ext = os.path.splitext(filename)[0]
            output_path = os.path.join(images_folder, f'{name_without_ext}.jpg')
            
            final_img.save(output_path, 'JPEG', quality=95)
            print(f"Processed: {filename} -> {name_without_ext}.jpg")
            
            # Delete the original file
            os.remove(file_path)
            
        except Exception as e:
            print(f"Error processing {filename}: {e}")

# Admin function
def update_list(): # Update python list from CSV
    cards.clear()
    if not os.path.exists('cards.csv'):
        return

    with open('cards.csv') as card_data:
        reader = csv.reader(card_data)
        try:
            next(reader)  # Skip header row
        except StopIteration:
            return # Empty file
            
        for row in reader:
            if row:
                # row structure: [Word, Word Initial, Word Final, Structure]
                cards.append({row[0]: [row[1:], f'{row[0]}.jpg']})

def perform_search(initial_sound, final_sound, structure_val): # Search functionality returning matching words
    matches = []
    initial_sound = initial_sound.lower().strip()
    final_sound = final_sound.lower().strip()
    structure_val = structure_val.lower().strip()
    
    for card in cards:
        word = list(card.keys())[0]
        card_data = card[word]
        # card_data[0] is [Word Initial, Word Final, Structure]
        current_initial = card_data[0][0]
        current_final = card_data[0][1]
        current_structure = card_data[0][2]
        
        # Check initial sound match (if provided)
        if initial_sound and current_initial != initial_sound:
            continue
            
        # Check final sound match (if provided)
        if final_sound and current_final != final_sound:
            continue
            
        # Check structure match (if provided)
        if structure_val and current_structure != structure_val:
            continue
            
        matches.append(word)
        
    return matches

# Admin function
def print_list(): # Update list from csv file and print
    update_list()
    print(cards)

# Admin function
def search(): # Search full card list, the structure can be skipped if desired
    word_init = input('Word initial sound: ').lower()
    word_final = input('Word final sound: ').lower()
    structure = input('Structure: ').lower()

    # Filter cards by word initial (value at index 1 in each entry's list)
    filtered_cards = []
    for card in cards:
        word = list(card.keys())[0]  # Get the word (key)
        card_data = card[word]  # Get the data [row[1:], image_path]
        word_initial = card_data[0][0]  # Get value at index 1 (word initial)
        word_final_sound = card_data[0][1]
        
        # Filter by word initial if provided
        if word_init and word_initial != word_init:
            continue
            
        # Filter by word final if provided
        if word_final and word_final_sound != word_final:
            continue
        
        filtered_cards.append(card)
    
    print(filtered_cards)

class AddCardDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Add New Card")
        self.setFixedSize(300, 350)
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Form inputs
        layout.addWidget(QLabel("Word:"))
        self.word_input = QLineEdit()
        layout.addWidget(self.word_input)
        
        layout.addWidget(QLabel("Initial Sound:"))
        self.initial_input = QLineEdit()
        layout.addWidget(self.initial_input)
        
        layout.addWidget(QLabel("Final Sound:"))
        self.final_input = QLineEdit()
        layout.addWidget(self.final_input)
        
        layout.addWidget(QLabel("Structure (e.g., cvc):"))
        self.structure_input = QLineEdit()
        layout.addWidget(self.structure_input)
        
        layout.addStretch()
        
        # Save Button
        self.save_btn = QPushButton("Save Card")
        self.save_btn.clicked.connect(self.save_card)
        layout.addWidget(self.save_btn)
        
        self.setLayout(layout)

    def save_card(self):
        word = self.word_input.text().lower().strip()
        word_initial = self.initial_input.text().lower().strip()
        word_final = self.final_input.text().lower().strip()
        structure = self.structure_input.text().lower().strip()
        
        if not word or not word_initial or not structure:
            QMessageBox.critical(self, "Error", "Please fill in all required fields")
            return

        try:
            with open('cards.csv', 'a', newline='') as card_data:
                writer = csv.writer(card_data)
                writer.writerow([word, word_initial, word_final, structure])
            
            QMessageBox.information(self, "Success", f"Added '{word}' successfully!")
            update_list() # Refresh the global list
            self.accept()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Could not save card: {e}")

class SLTWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SLT Word Cards Search")
        self.resize(400, 550)
        self.setup_ui()
        self.current_print_words = []

    def setup_ui(self):
        main_layout = QVBoxLayout()
        
        # Input Group
        input_group = QGroupBox("Search Criteria")
        input_layout = QGridLayout()
        
        input_layout.addWidget(QLabel("Word Initial Sound:"), 0, 0)
        self.initial_entry = QLineEdit()
        input_layout.addWidget(self.initial_entry, 0, 1)
        
        input_layout.addWidget(QLabel("Word Final Sound:"), 1, 0)
        self.final_entry = QLineEdit()
        input_layout.addWidget(self.final_entry, 1, 1)
        
        input_layout.addWidget(QLabel("Structure (e.g., cvc):"), 2, 0)
        self.structure_entry = QLineEdit()
        input_layout.addWidget(self.structure_entry, 2, 1)
        
        input_group.setLayout(input_layout)
        main_layout.addWidget(input_group)
        
        # Buttons Layout
        btn_layout = QHBoxLayout()
        self.search_btn = QPushButton("Search")
        self.search_btn.clicked.connect(self.on_search)
        btn_layout.addWidget(self.search_btn)
        
        self.add_btn = QPushButton("Add Card")
        self.add_btn.clicked.connect(self.open_add_card)
        btn_layout.addWidget(self.add_btn)
        
        main_layout.addLayout(btn_layout)
        
        # Results Group
        results_group = QGroupBox("Matching Words")
        results_layout = QVBoxLayout()
        self.results_list = QListWidget()
        results_layout.addWidget(self.results_list)
        results_group.setLayout(results_layout)
        
        main_layout.addWidget(results_group)
        
        # Instance Count Input
        count_layout = QHBoxLayout()
        count_layout.addWidget(QLabel("Instance Count:"))
        self.instance_count_input = QLineEdit("1")
        self.instance_count_input.setFixedWidth(50)
        count_layout.addWidget(self.instance_count_input)
        count_layout.addStretch()
        main_layout.addLayout(count_layout)
        
        # Export Button
        self.export_btn = QPushButton("Create List from Selection")
        self.export_btn.clicked.connect(self.create_list_from_selection)
        main_layout.addWidget(self.export_btn)
        
        # Status Label
        self.status_label = QLabel("")
        self.status_label.setFrameStyle(QLabel.Shape.Panel | QLabel.Shadow.Sunken)
        main_layout.addWidget(self.status_label)
        
        self.setLayout(main_layout)

    def on_search(self):
        initial = self.initial_entry.text()
        final = self.final_entry.text()
        structure = self.structure_entry.text()
        
        results = perform_search(initial, final, structure)
        
        self.results_list.clear()
        
        for word in results:
            item = QListWidgetItem(word)
            item.setFlags(item.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            item.setCheckState(Qt.CheckState.Unchecked)
            self.results_list.addItem(item)
            
        self.status_label.setText(f"Found {len(results)} matches.")

    def create_list_from_selection(self):
        selected_words = []
        for index in range(self.results_list.count()):
            item = self.results_list.item(index)
            if item.checkState() == Qt.CheckState.Checked:
                selected_words.append(item.text())
        
        if not selected_words:
            QMessageBox.information(self, "Selection", "No words selected.")
            return

        # Get instance count
        try:
            count = int(self.instance_count_input.text())
            if count < 1:
                count = 1
        except ValueError:
            count = 1
            
        # Multiply selection by count
        final_list = []
        for _ in range(count):
            final_list.extend(selected_words)
        
        self.current_print_words = final_list
        
        # Setup Printer
        printer = QPrinter(QPrinter.PrinterMode.HighResolution)
        # Set A4 Page
        printer.setPageSize(QPageSize(QPageSize.PageSizeId.A4))
        
        preview = QPrintPreviewDialog(printer, self)
        preview.paintRequested.connect(self.handle_print_paint_request)
        preview.setMinimumSize(800, 600)
        preview.exec()

    def handle_print_paint_request(self, printer):
        painter = QPainter(printer)
        
        page_rect = printer.pageLayout().paintRectPixels(printer.resolution())
        page_width = page_rect.width()
        page_height = page_rect.height()
        
        # Define grid
        cols = 3
        rows = 4
        
        margin_x = page_width * 0.05
        margin_y = page_height * 0.05
        
        working_width = page_width - (2 * margin_x)
        working_height = page_height - (2 * margin_y)
        
        cell_width = working_width / cols
        cell_height = working_height / rows
        
        # Card size: Fit within cell but maintain square if possible, or fill?
        # Requirement: "300x300 pixels". We will assume square aspect ratio.
        # We leave some padding.
        card_size = min(cell_width, cell_height) * 0.9
        
        x_offset = (cell_width - card_size) / 2
        y_offset = (cell_height - card_size) / 2
        
        current_col = 0
        current_row = 0
        
        # Pen for border - scaled relative to card size to appear as ~3px on 500px image
        # If card_size is large (e.g. 1000px on high res printer), 0.6% is 6px. 
        # Standard 3px on 500px is 0.6%.
        border_pen = QPen(Qt.GlobalColor.black)
        border_pen.setWidth(max(1, int(card_size * 0.006))) 
        
        painter.setPen(border_pen)

        for i, word in enumerate(self.current_print_words):
            if i > 0 and i % (cols * rows) == 0:
                printer.newPage()
                current_col = 0
                current_row = 0
            
            # cell origin (relative to margin)
            x = margin_x + (current_col * cell_width) + x_offset
            y = margin_y + (current_row * cell_height) + y_offset
            
            # Draw Image
            img_name = f"{word}.jpg"
            img_path = os.path.join("images", img_name)
            if not os.path.exists(img_path):
                img_path = os.path.join("images", "no_image.jpg")
                
            if os.path.exists(img_path):
                pixmap = QPixmap(img_path)
                if not pixmap.isNull():
                    # Draw pixmap into the rect
                    target_rect = QRectF(x, y, card_size, card_size)
                    painter.drawPixmap(target_rect.toRect(), pixmap)
                    
                    # Draw Border
                    painter.drawRect(target_rect)
            
            # Move to next
            current_col += 1
            if current_col >= cols:
                current_col = 0
                current_row += 1
                
        painter.end()

    def open_add_card(self):
        dialog = AddCardDialog(self)
        if dialog.exec():
            # If card was added, maybe re-run search?
            # For now, just keeping list updated via update_list called inside dialog
            pass

def main():
    # Run formatting check
    if os.path.exists('unformatted'):
         if any(os.path.isfile(os.path.join('unformatted', f)) for f in os.listdir('unformatted')):
             print("Formatting images...")
             format_images()
    
    # Load data
    update_list()
    
    # Start GUI
    app = QApplication(sys.argv)
    window = SLTWindow()
    window.show()
    sys.exit(app.exec())

# Run formatting check
if os.path.exists('unformatted'):
    if any(os.path.isfile(os.path.join('unformatted', f)) for f in os.listdir('unformatted')):
        print("Formatting images...")
        format_images()

if __name__ == '__main__':
    main()