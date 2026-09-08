with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/StudioScreen.swift', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "ScrollView {" in line and "var body" not in line:
        # Wrap everything from ScrollView down to .task in a condition
        pass
