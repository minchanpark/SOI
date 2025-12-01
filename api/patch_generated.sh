#!/bin/bash
# OpenAPI Generator로 생성된 코드의 알려진 버그를 자동으로 패치하는 스크립트
# 
# 사용법:
#   chmod +x patch_generated.sh
#   ./patch_generated.sh

echo "🔧 Patching generated code for multipart file handling..."

FILE="generated/lib/api/api_api.dart"

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  echo "   Make sure you've run 'openapi-generator generate' first."
  exit 1
fi

# 백업 생성
cp "$FILE" "${FILE}.backup"
echo "📦 Backup created: ${FILE}.backup"

# files (복수) 파일 업로드 버그 수정
# OpenAPI Generator가 List<MultipartFile>을 잘못 처리하는 문제 해결
echo "🔧 Fixing multiple files upload bug..."

# Python을 사용하여 더 정확한 패치 수행
python3 << 'PYTHON_SCRIPT'
import re

file_path = "generated/lib/api/api_api.dart"

with open(file_path, 'r') as f:
    content = f.read()

# 패턴 1: if (files != null) -> if (files.isNotEmpty)
content = re.sub(
    r'if \(files != null\)',
    'if (files.isNotEmpty)',
    content
)

# 패턴 2: 잘못된 multipart 처리를 수정
# mp.fields[r'files'] = files.field;
# mp.files.add(files);
# 를
# mp.files.addAll(files);
# 로 변경
content = re.sub(
    r"mp\.fields\[r'files'\] = files\.field;\s*\n\s*mp\.files\.add\(files\);",
    "mp.files.addAll(files);",
    content
)

with open(file_path, 'w') as f:
    f.write(content)

print("✅ Python patch applied successfully!")
PYTHON_SCRIPT

echo "✅ Patch complete!"
echo ""
echo "📝 Changes made:"
echo "   - Fixed List<MultipartFile> handling for multiple file uploads"
echo "   - Changed 'files != null' to 'files.isNotEmpty'"
echo "   - Changed 'mp.files.add(files)' to 'mp.files.addAll(files)'"
echo "   - Removed incorrect 'files.field' reference"
echo ""
echo "🔄 Next steps:"
echo "   cd generated && dart analyze"
