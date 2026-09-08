import re

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'r') as f:
    content = f.read()

content = "import SwiftUI\n" + content

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'w') as f:
    f.write(content)

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/Models.swift', 'r') as f:
    content = f.read()

content = re.sub(r'let ownerId: String', r'var ownerId: String', content)

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/Models.swift', 'w') as f:
    f.write(content)
