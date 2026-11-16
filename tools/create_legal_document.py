from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "CraveCircle Privacy Notice and Terms Draft.docx"


def shade(cell, color):
    properties = cell._tc.get_or_add_tcPr()
    shading = OxmlElement("w:shd")
    shading.set(qn("w:fill"), color)
    properties.append(shading)


def set_cell_padding(cell, top=100, start=130, bottom=100, end=130):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    margins = tc_pr.first_child_found_in("w:tcMar")
    if margins is None:
        margins = OxmlElement("w:tcMar")
        tc_pr.append(margins)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = margins.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            margins.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def add_run(paragraph, text, bold=False, italic=False):
    run = paragraph.add_run(text)
    run.bold = bold
    run.italic = italic
    run.font.name = "Aptos"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Aptos")
    return run


def add_paragraph(document, text="", style=None, before=0, after=7):
    paragraph = document.add_paragraph(style=style)
    paragraph.paragraph_format.space_before = Pt(before)
    paragraph.paragraph_format.space_after = Pt(after)
    paragraph.paragraph_format.line_spacing = 1.15
    add_run(paragraph, text)
    return paragraph


def add_bullet(document, text):
    paragraph = document.add_paragraph(style="List Bullet")
    paragraph.paragraph_format.space_after = Pt(4)
    paragraph.paragraph_format.line_spacing = 1.1
    add_run(paragraph, text)
    return paragraph


def add_heading(document, text, level=1):
    paragraph = document.add_paragraph(style=f"Heading {level}")
    paragraph.paragraph_format.space_before = Pt(17 if level == 1 else 10)
    paragraph.paragraph_format.space_after = Pt(6)
    add_run(paragraph, text, bold=True)
    return paragraph


def add_page_number(paragraph):
    field = OxmlElement("w:fldSimple")
    field.set(qn("w:instr"), "PAGE")
    paragraph._p.append(field)


def add_header_footer(section):
    header = section.header.paragraphs[0]
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run("CraveCircle  |  Privacy Notice and Terms Draft")
    run.font.name = "Aptos"
    run.font.size = Pt(8.5)
    run.font.color.rgb = RGBColor(90, 90, 90)

    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer.paragraph_format.space_before = Pt(0)
    run = footer.add_run("Draft for legal review  •  Page ")
    run.font.name = "Aptos"
    run.font.size = Pt(8.5)
    run.font.color.rgb = RGBColor(90, 90, 90)
    add_page_number(footer)


def build_document():
    document = Document()
    section = document.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.82)
    section.right_margin = Inches(0.82)
    add_header_footer(section)

    styles = document.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Aptos")
    normal.font.size = Pt(10.8)
    for name, size in (("Title", 25), ("Heading 1", 16), ("Heading 2", 12)):
        style = styles[name]
        style.font.name = "Aptos Display" if name == "Title" else "Aptos"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), style.font.name)
        style.font.size = Pt(size)
        style.font.color.rgb = RGBColor(0, 0, 0)

    title = document.add_paragraph(style="Title")
    title.alignment = WD_ALIGN_PARAGRAPH.LEFT
    title.paragraph_format.space_after = Pt(8)
    add_run(title, "CraveCircle Privacy Notice and Terms Draft", bold=True)

    subtitle = add_paragraph(
        document,
        "A plain language explanation of private recipe imports and responsible use",
        before=0,
        after=18,
    )
    subtitle.runs[0].italic = True
    subtitle.runs[0].font.color.rgb = RGBColor(75, 75, 75)

    meta = document.add_table(rows=2, cols=2)
    meta.autofit = False
    meta.columns[0].width = Inches(1.55)
    meta.columns[1].width = Inches(5.65)
    rows = [("Document status", "Draft for founder and qualified legal review"),
            ("Effective date", "[INSERT EFFECTIVE DATE BEFORE RELEASE]")]
    for row, (label, value) in zip(meta.rows, rows):
        for cell in row.cells:
            set_cell_padding(cell)
        shade(row.cells[0], "E9E5E0")
        add_run(row.cells[0].paragraphs[0], label, bold=True)
        add_run(row.cells[1].paragraphs[0], value)
    document.add_paragraph()

    add_heading(document, "Important information before release", 1)
    add_paragraph(
        document,
        "This is a product-policy draft, not legal advice. Before it is shown as a final legal notice, "
        "replace the placeholders for the legal entity, postal address, support email, governing law, "
        "and effective date. Confirm that the deployed backend retention controls match this document."
    )

    add_heading(document, "Privacy Notice", 1)
    add_paragraph(
        document,
        "CraveCircle is a recipe-organising app provided by [LEGAL ENTITY] (CraveCircle, we, us). "
        "This notice explains how the iOS app handles information when you use its recipe, cooking, "
        "library, and import features."
    )

    add_heading(document, "Information we process", 2)
    for item in [
        "Account information, such as an email address and basic profile details, when you choose to create an account.",
        "Recipes, grocery lists, collections, comments, and recipe photos that you intentionally create or save.",
        "A recipe link that you intentionally paste or share for an import.",
        "The structured recipe text, ingredient list, directions, and nutrition estimate created from an import.",
    ]:
        add_bullet(document, item)

    add_heading(document, "How recipe imports work", 2)
    add_paragraph(
        document,
        "When you import a link, CraveCircle sends the link to its self-hosted import relay. The relay "
        "uses the selected public cooking post only to extract food-related recipe information and return "
        "a structured recipe to your device. It does not operate a public video or audio library and does "
        "not add imported recipes to the community catalog."
    )
    add_paragraph(
        document,
        "An import result is a private hand-off. After the importing app retrieves the structured recipe, "
        "the relay removes the temporary result and associated job record. If delivery is interrupted, a "
        "temporary result is retained only for a limited period to allow retrieval, then cleared under the "
        "service retention controls. Imported recipes stay in your private library. They cannot be published "
        "or shared with other CraveCircle users. When available, the Watch control opens the original source."
    )

    # Keep the permissions table intact rather than leaving its first row stranded at the end of
    # the preceding page.
    document.add_page_break()
    add_heading(document, "On device processing and permissions", 2)
    permission_table = document.add_table(rows=1, cols=2)
    permission_table.style = "Table Grid"
    permission_table.autofit = False
    permission_table.columns[0].width = Inches(1.65)
    permission_table.columns[1].width = Inches(5.55)
    headers = ("Feature", "How it is handled")
    for cell, value in zip(permission_table.rows[0].cells, headers):
        shade(cell, "303030")
        set_cell_padding(cell)
        run = cell.paragraphs[0].add_run(value)
        run.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
    entries = [
        ("Camera", "Optional hands-free cooking gesture frames are processed on device. CraveCircle does not record or transmit a camera video stream."),
        ("Microphone and speech", "Optional voice controls and supported on-device transcription are processed on device. CraveCircle does not create a voice recording library."),
        ("Photo library", "Used only for cooking media or a recipe photo you choose. A chosen recipe cover stays with that recipe; a processing-only video is not saved as a library item."),
    ]
    for index, (feature, handling) in enumerate(entries):
        cells = permission_table.add_row().cells
        for cell in cells:
            set_cell_padding(cell)
        if index % 2 == 1:
            for cell in cells:
                shade(cell, "F5F3F1")
        add_run(cells[0].paragraphs[0], feature, bold=True)
        add_run(cells[1].paragraphs[0], handling)

    add_heading(document, "Use and disclosure", 2)
    add_paragraph(
        document,
        "We use information to operate your private library, render recipe details, calculate optional "
        "nutrition estimates, provide account and support functions, and protect the service. We do not "
        "sell personal information, use behavioural advertising, run cross-app tracking, or include third-party analytics SDKs for behavioural advertising."
    )
    add_paragraph(
        document,
        "CraveCircle uses a self-hosted backend for link imports and Supabase services for account and data "
        "functions where enabled. We may disclose information if required by law or reasonably necessary to "
        "protect the service, users, or others."
    )

    add_heading(document, "Retention deletion and contact", 2)
    add_paragraph(
        document,
        "You can delete a locally stored recipe from the app. To request account or backend-content deletion, "
        "contact [SUPPORT EMAIL]. We retain information only as reasonably necessary to operate the service, "
        "resolve issues, meet legal obligations, and enforce these terms. CraveCircle is not directed to children under 13."
    )

    document.add_page_break()
    add_heading(document, "Terms of Service", 1)
    add_paragraph(document, "Effective date: [INSERT EFFECTIVE DATE BEFORE RELEASE]")
    add_paragraph(document, "By using CraveCircle, you agree to these Terms. If you do not agree, do not use the service.")

    add_heading(document, "Accounts and acceptable use", 2)
    add_paragraph(
        document,
        "You are responsible for your account and for using CraveCircle lawfully. Do not attempt to access another "
        "person's account, interfere with the service, upload harmful material, or infringe another person's rights."
    )

    add_heading(document, "Third party recipe sources", 2)
    add_paragraph(
        document,
        "You may import only content that you are permitted to access and process. You remain responsible for "
        "following the source platform's terms and applicable law. CraveCircle extracts structured, food-related "
        "recipe information from a link you provide. It does not grant you rights in the source video, audio, images, creator identity, or other third-party content."
    )
    add_paragraph(
        document,
        "Imported recipes are private library references. They cannot be published to the CraveCircle catalog or "
        "shared with another CraveCircle account. Use Watch to return to the original source when available. Only "
        "original recipes created in Studio and eligible under the app's rules may be submitted for publication."
    )

    add_heading(document, "Your original content", 2)
    add_paragraph(
        document,
        "You retain ownership of original content you create. You grant CraveCircle the limited rights needed to "
        "store, display, and transmit that content solely to operate the service. You must not submit content that "
        "is unlawful, defamatory, harmful, or infringing. We may remove or restrict content or accounts that violate "
        "these Terms or create a safety, legal, or operational risk."
    )

    add_heading(document, "Nutrition and cooking safety", 2)
    add_paragraph(
        document,
        "Nutrition values are automatic estimates based on ingredient text. They may be incomplete or inaccurate and "
        "are not medical, dietary, allergy, or professional nutritional advice. Check allergens, ingredient safety, "
        "cooking temperatures, and recipe suitability yourself."
    )

    add_heading(document, "Disclaimers and liability", 2)
    add_paragraph(
        document,
        "CraveCircle is provided on an as is and as available basis to the extent permitted by law. We do not guarantee "
        "that an import will work, that a recipe is complete or safe, or that third-party links will remain available. "
        "To the maximum extent permitted by law, [LEGAL ENTITY] is not liable for indirect, incidental, special, consequential, or punitive damages arising from use of the service."
    )

    add_heading(document, "Changes governing law and contact", 2)
    add_paragraph(
        document,
        "We may suspend or terminate access for violations, security concerns, or service changes. We may update these "
        "Terms by posting an updated effective date. These Terms are governed by the laws of [JURISDICTION], subject "
        "to applicable consumer protections. Contact: [LEGAL ENTITY, POSTAL ADDRESS, SUPPORT EMAIL]."
    )

    add_heading(document, "Support information", 1)
    add_paragraph(document, "For help, contact [SUPPORT EMAIL]. Target response time: [RESPONSE TIME].")
    add_heading(document, "Frequently asked questions", 2)
    faqs = [
        ("How does a link import work?", "You choose a recipe link. CraveCircle processes it into recipe text and sends the result to your private library. The import is not publicly published."),
        ("Does CraveCircle keep the source video or audio?", "The import relay uses temporary working media for processing. It does not operate a public media archive, and the structured result is removed after delivery to the app."),
        ("Can I share an imported recipe?", "No. Imported recipes are private references. Use Watch to open the original source when available."),
        ("How do I delete data?", "Delete a locally stored recipe from the app. For account or backend-content requests, email [SUPPORT EMAIL]."),
    ]
    for question, answer in faqs:
        paragraph = add_paragraph(document, before=5, after=3)
        add_run(paragraph, question + " ", bold=True)
        add_run(paragraph, answer)

    add_heading(document, "Release checklist", 1)
    for item in [
        "Obtain qualified legal review for the final entity, jurisdiction, and consumer-law wording.",
        "Insert a monitored support email, legal entity name, and postal address.",
        "Confirm the deployed import relay enforces temporary-result deletion and retention limits.",
        "Publish the final approved version in the app as a readable document or PDF.",
    ]:
        add_bullet(document, item)

    document.save(OUTPUT)
    return OUTPUT


if __name__ == "__main__":
    print(build_document())
