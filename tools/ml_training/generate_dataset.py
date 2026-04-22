"""
Beti — Fase 3.1 TFLite
Generador de dataset sintético para clasificación de categorías.

Entrada: data/keyword_map.json
Salida:  output/train_dataset.json (examples balanceados por categoría)
         output/vocab.json          (vocabulario token → índice)
         output/labels.json         (índice → CategoryType.name)

Metodología (Módulo 4 — Soft Computing):
1. Expansión sintética: cada keyword base genera N variantes
   - Con números: "uber 150", "taco 45 pesos"
   - Con prefijos de pago: "pago de uber", "compra en uber"
   - Con errores de tipeo controlados (opcional)
2. Balanceo: todas las categorías tienen el mismo #ejemplos (undersampling)
3. Vocabulario: tokenización simple por espacios, lowercase, sin acentos
4. Hash trick descartado — usamos vocab explícito de tamaño fijo (2000 tokens)
"""
import json
import random
import re
import unicodedata
from collections import Counter
from pathlib import Path

# ═══════════════════════════════════════════════════════════
# Configuración
# ═══════════════════════════════════════════════════════════
SEED = 42
EXAMPLES_PER_CATEGORY = 400   # Balanceo forzado
MAX_VOCAB_SIZE = 2000         # Top-N tokens más frecuentes
MIN_TOKEN_FREQ = 2            # Token debe aparecer >= 2 veces
MAX_SEQ_LENGTH = 8            # Padding/truncation para input TFLite

SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR / "data"
OUTPUT_DIR = SCRIPT_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

KEYWORD_MAP_PATH = DATA_DIR / "keyword_map.json"
TRAIN_OUT = OUTPUT_DIR / "train_dataset.json"
VOCAB_OUT = OUTPUT_DIR / "vocab.json"
LABELS_OUT = OUTPUT_DIR / "labels.json"

# Tokens especiales (reservados)
PAD_TOKEN = "<pad>"   # idx 0
UNK_TOKEN = "<unk>"   # idx 1

random.seed(SEED)


# ═══════════════════════════════════════════════════════════
# Normalización (idéntica a CategorizationEngine._normalize en Dart)
# ═══════════════════════════════════════════════════════════
def normalize(text: str) -> str:
    """Debe ser EXACTAMENTE igual al _normalize de Dart."""
    text = text.lower()
    # Remover acentos
    text = "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )
    # ü → u, ñ → n (unicodedata ya quitó los diacríticos, pero ñ es letra base)
    text = text.replace("ñ", "n").replace("ü", "u")
    # No-alfanum → espacio
    text = re.sub(r"[^\w\s]", " ", text)
    # Colapsar espacios
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tokenize(text: str) -> list[str]:
    """Split por espacios después de normalizar."""
    return [t for t in normalize(text).split() if len(t) >= 2]


# ═══════════════════════════════════════════════════════════
# Expansión sintética
# ═══════════════════════════════════════════════════════════
PAYMENT_PREFIXES = [
    "", "", "",  # Mayor peso a keyword sola
    "pago de ", "compra en ", "gasto en ", "pago a ",
    "cobro de ", "recibo de ", "cargo de ",
]

PAYMENT_SUFFIXES = [
    "", "", "",  # Mayor peso a keyword sola
    " en efectivo", " con tarjeta", " debito", " credito",
]

AMOUNT_PATTERNS = [
    "",  # Sin monto
    " {n}",
    " {n} pesos",
    " ${n}",
    " mxn {n}",
    " por {n}",
]


def random_amount() -> int:
    """Monto realista mexicano."""
    # Distribución ajustada: más gastos pequeños que grandes
    ranges = [
        (5, 50, 0.3),      # Transporte corto, café
        (50, 300, 0.4),    # Comida, compras pequeñas
        (300, 1500, 0.2),  # Ropa, salud
        (1500, 10000, 0.1) # Renta, electrónicos
    ]
    r = random.random()
    cum = 0
    for lo, hi, w in ranges:
        cum += w
        if r <= cum:
            return random.randint(lo, hi)
    return random.randint(50, 300)


def augment(keyword: str) -> str:
    """Genera una variante sintética de un keyword."""
    prefix = random.choice(PAYMENT_PREFIXES)
    suffix = random.choice(PAYMENT_SUFFIXES)
    amount_template = random.choice(AMOUNT_PATTERNS)
    amount_str = (
        amount_template.format(n=random_amount())
        if amount_template else ""
    )
    return f"{prefix}{keyword}{amount_str}{suffix}".strip()


# ═══════════════════════════════════════════════════════════
# Pipeline principal
# ═══════════════════════════════════════════════════════════
def generate_examples(keyword_map: dict) -> list[dict]:
    """Genera ejemplos balanceados por categoría."""
    examples = []

    for category, keywords in keyword_map.items():
        cat_examples = []

        # 1) Siempre incluir cada keyword tal cual (caso base)
        for kw in keywords:
            cat_examples.append({"text": normalize(kw), "label": category})

        # 2) Expandir hasta llegar a EXAMPLES_PER_CATEGORY
        while len(cat_examples) < EXAMPLES_PER_CATEGORY:
            kw = random.choice(keywords)
            variant = augment(kw)
            cat_examples.append({"text": normalize(variant), "label": category})

        # 3) Si hay MÁS keywords que cupo (caso raro), sample aleatorio
        if len(cat_examples) > EXAMPLES_PER_CATEGORY:
            cat_examples = random.sample(cat_examples, EXAMPLES_PER_CATEGORY)

        examples.extend(cat_examples)
        print(f"  {category:<20} → {len(cat_examples)} ejemplos")

    random.shuffle(examples)
    return examples


def build_vocab(examples: list[dict]) -> dict:
    """Construye vocab: token → índice. Reserva 0=PAD, 1=UNK."""
    counter = Counter()
    for ex in examples:
        counter.update(tokenize(ex["text"]))

    # Filtrar por frecuencia mínima y tomar top-N
    frequent = [
        (tok, freq) for tok, freq in counter.most_common()
        if freq >= MIN_TOKEN_FREQ
    ]
    frequent = frequent[: MAX_VOCAB_SIZE - 2]  # -2 por PAD y UNK

    vocab = {PAD_TOKEN: 0, UNK_TOKEN: 1}
    for idx, (tok, _) in enumerate(frequent, start=2):
        vocab[tok] = idx

    return vocab


def build_labels(keyword_map: dict) -> dict:
    """Índice → nombre de categoría. Orden determinista."""
    # Ordenado para que el mapeo sea consistente entre runs
    ordered = sorted(keyword_map.keys())
    return {str(i): cat for i, cat in enumerate(ordered)}


# ═══════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════
def main():
    print("═" * 60)
    print("Beti ML — Generación de Dataset")
    print("═" * 60)

    if not KEYWORD_MAP_PATH.exists():
        raise FileNotFoundError(
            f"Falta {KEYWORD_MAP_PATH}. "
            "Créalo manualmente (ver instrucciones de Claude)."
        )

    with open(KEYWORD_MAP_PATH, encoding="utf-8") as f:
        keyword_map = json.load(f)

    print(f"\n📂 Keyword map cargado: {len(keyword_map)} categorías")
    print("\n🔨 Generando ejemplos sintéticos...")
    examples = generate_examples(keyword_map)

    print(f"\n✅ Total ejemplos: {len(examples)}")
    print(f"   Balance: {EXAMPLES_PER_CATEGORY} por categoría")

    print("\n📖 Construyendo vocabulario...")
    vocab = build_vocab(examples)
    print(f"   Vocab size: {len(vocab)} tokens "
          f"(max {MAX_VOCAB_SIZE}, min_freq {MIN_TOKEN_FREQ})")

    print("\n🏷️  Construyendo labels...")
    labels = build_labels(keyword_map)
    print(f"   Num clases: {len(labels)}")

    # Metadata útil para el entrenamiento
    dataset = {
        "meta": {
            "num_examples": len(examples),
            "num_classes": len(labels),
            "vocab_size": len(vocab),
            "max_seq_length": MAX_SEQ_LENGTH,
            "seed": SEED,
        },
        "examples": examples,
    }

    with open(TRAIN_OUT, "w", encoding="utf-8") as f:
        json.dump(dataset, f, ensure_ascii=False, indent=2)
    with open(VOCAB_OUT, "w", encoding="utf-8") as f:
        json.dump(vocab, f, ensure_ascii=False, indent=2)
    with open(LABELS_OUT, "w", encoding="utf-8") as f:
        json.dump(labels, f, ensure_ascii=False, indent=2)

    print(f"\n💾 Artefactos guardados:")
    print(f"   {TRAIN_OUT.relative_to(SCRIPT_DIR)}")
    print(f"   {VOCAB_OUT.relative_to(SCRIPT_DIR)}")
    print(f"   {LABELS_OUT.relative_to(SCRIPT_DIR)}")

    # Sanity check
    print("\n🔍 Muestra aleatoria (5 ejemplos):")
    for ex in random.sample(examples, 5):
        print(f"   [{ex['label']:<15}] {ex['text']}")


if __name__ == "__main__":
    main()