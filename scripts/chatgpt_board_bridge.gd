extends RefCounted
# Human-mediated ChatGPT generation. No API, cookie, login automation or GPU service.
const COLS: int = 4
const ROWS: int = 2

func request_prompt(story: String, subject: String, style: String, kind: String = "board", index: int = -1, total: int = 8) -> String:
    var context: String = "KARMA ONE — demande de vrais dessins générés.\nSujet/idée : " + subject.strip_edges() + "\nHistoire complète : " + story.strip_edges() + "\nStyle : " + style + ".\n"
    context += "Si une image est jointe, elle est la référence permanente. Conserve l'identité, les proportions, les vêtements, accessoires, décors et les relations des sujets. Respecte leur morphologie : une banane reste une banane, pas un humain déguisé. Aucun squelette humain imposé aux animaux ou objets.\n"
    if kind == "reference":
        return context + "Génère maintenant une seule image de départ fidèle à cette description. Pas de planche ni de texte. Ne présente pas une description comme une image produite."
    if kind == "replacement":
        return context + "Génère UNE SEULE image de remplacement pour le dessin %d sur %d (ordre chronologique de gauche à droite puis ligne suivante). Représente cet instant précis de l'action ; garde l'identité et le cadrage. Pas de grille, pas de texte. Les autres dessins seront conservés. Si la phase ou l'apparence est ambiguë, demande une précision avant génération." % [index + 1, total]
    return context + "Génère une planche de HUIT images : exactement 4 colonnes et 2 lignes régulières de même taille. Lecture de gauche à droite, puis ligne suivante. Décompose l'histoire en huit états successifs physiquement cohérents ; dessine réellement les nouvelles postures et interactions. Pas de simple zoom ou rotation de la même image. Cadrage stable, sujets entiers, progression visible. Remplis les 8 cases jusqu'aux bords, sans marge, gouttière, bordure, texte, numéro ou titre. Vise 2048×1024 pixels pour la planche. Ne prétends pas avoir produit des dessins si le générateur est indisponible."

func split_board(sheet: Image, columns: int = COLS, rows: int = ROWS) -> Dictionary:
    if sheet == null or sheet.is_empty() or columns < 1 or rows < 1 or columns > 6 or rows > 6 or columns * rows < 2 or columns * rows > 24:
        return {"ok": false, "error": "Planche ou grille invalide."}
    if sheet.get_width() / columns < 256 or sheet.get_height() / rows < 256:
        return {"ok": false, "error": "Cases trop petites : 256 pixels minimum par côté. Importe l'image originale, pas sa capture d'écran."}
    var images: Array[Image] = []
    var hashes: Dictionary = {}
    for row in range(rows):
        for col in range(columns):
            var x0: int = roundi(float(col) * sheet.get_width() / columns)
            var x1: int = roundi(float(col + 1) * sheet.get_width() / columns)
            var y0: int = roundi(float(row) * sheet.get_height() / rows)
            var y1: int = roundi(float(row + 1) * sheet.get_height() / rows)
            var image: Image = sheet.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
            var technical: Dictionary = load("res://scripts/drawing_quality_gate.gd").new().inspect(image)
            if not technical.get("ok", false):
                return {"ok": false, "error": "Une case est vide ou uniforme. Vérifie la grille. Ancienne planche conservée."}
            var hasher := HashingContext.new()
            hasher.start(HashingContext.HASH_SHA256)
            hasher.update(image.get_data())
            var digest: String = hasher.finish().hex_encode()
            if hashes.has(digest):
                return {"ok": false, "error": "Deux cases sont identiques. Vérifie la grille ou demande de vrais états successifs. Ancienne planche conservée."}
            hashes[digest] = true
            images.append(image)
    return {"ok": true, "images": images, "identity_verified": false, "layout_verified": false, "origin": "external_chatgpt_user_import"}

func save_board(sheet: Image, folder: String, columns: int = COLS, rows: int = ROWS) -> Dictionary:
    var result: Dictionary = split_board(sheet, columns, rows)
    if not result.get("ok", false):
        return result
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        return {"ok": false, "error": "Sauvegarde de la planche impossible."}
    var paths: Array[String] = []
    for i in range(result["images"].size()):
        var path: String = folder.path_join("frame_%04d.png" % i)
        if result["images"][i].save_png(path) != OK:
            return {"ok": false, "error": "Sauvegarde interrompue. Ancienne planche conservée."}
        paths.append(path)
    var meta: Dictionary = {"origin": result["origin"], "columns": columns, "rows": rows, "identity_verified": false, "layout_verified": false, "human_approved": false, "files": paths, "note": "Découpe technique seulement. Inspection humaine obligatoire ; provenance déclarée par l'utilisateur."}
    var file := FileAccess.open(folder.path_join("import.json"), FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "Journal de planche inaccessible."}
    file.store_string(JSON.stringify(meta, "  "))
    file.close()
    return {"ok": true, "paths": paths, "count": paths.size(), "metadata": meta}
