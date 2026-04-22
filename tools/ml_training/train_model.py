"""
Beti — Fase 3.1 TFLite
Entrenamiento del clasificador de texto (Embedding + GAP + Dense).

Entrada:  output/train_dataset.json
          output/vocab.json
          output/labels.json

Salida:   output/beti_categorizer.tflite   (modelo final para Flutter)
          output/training_report.json      (métricas para defensa académica)

Arquitectura (Módulo 4.2 — Modelo matemático):
    Input (batch, 8)                    # seq_length = 8 tokens
        ↓
    Embedding(vocab_size, 16)           # E ∈ ℝ^(V×16)
        ↓
    GlobalAveragePooling1D              # h = (1/n) Σᵢ E[xᵢ]
        ↓
    Dense(32, relu)                     # h' = ReLU(W₁·h + b₁)
        ↓
    Dropout(0.3)                        # Regularización
        ↓
    Dense(num_classes, softmax)         # ŷ = softmax(W₂·h' + b₂)

Loss:      Sparse categorical cross-entropy
           L = -Σ yᵢ log(ŷᵢ)
Optimizer: Adam (lr=0.001, β₁=0.9, β₂=0.999)
Métricas:  Accuracy + Top-3 accuracy
"""
import json
import random
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models

# ═══════════════════════════════════════════════════════════
# Configuración
# ═══════════════════════════════════════════════════════════
SEED = 42
EMBEDDING_DIM = 16
DENSE_UNITS = 32
DROPOUT_RATE = 0.3
MAX_SEQ_LENGTH = 8         # Debe coincidir con generate_dataset.py

BATCH_SIZE = 64
EPOCHS = 30
VALIDATION_SPLIT = 0.15
TEST_SPLIT = 0.10          # Del total, para reporte académico final
LEARNING_RATE = 0.001
EARLY_STOP_PATIENCE = 5

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "output"

TRAIN_IN = OUTPUT_DIR / "train_dataset.json"
VOCAB_IN = OUTPUT_DIR / "vocab.json"
LABELS_IN = OUTPUT_DIR / "labels.json"

MODEL_OUT = OUTPUT_DIR / "beti_categorizer.tflite"
REPORT_OUT = OUTPUT_DIR / "training_report.json"
H5_CHECKPOINT = OUTPUT_DIR / "model_checkpoint.h5"

# Tokens especiales (deben coincidir con generate_dataset.py)
PAD_IDX = 0
UNK_IDX = 1

# Reproducibilidad
random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)


# ═══════════════════════════════════════════════════════════
# Tokenización (espeja el TextPreprocessor de Dart)
# ═══════════════════════════════════════════════════════════
def tokenize(text: str) -> list[str]:
    """Asume que el texto ya viene normalizado desde generate_dataset."""
    return [t for t in text.split() if len(t) >= 2]


def text_to_sequence(text: str, vocab: dict) -> list[int]:
    """Convierte texto → secuencia de índices con padding/truncation."""
    tokens = tokenize(text)
    ids = [vocab.get(tok, UNK_IDX) for tok in tokens]

    # Truncation
    if len(ids) > MAX_SEQ_LENGTH:
        ids = ids[:MAX_SEQ_LENGTH]

    # Padding a la derecha con PAD_IDX=0
    while len(ids) < MAX_SEQ_LENGTH:
        ids.append(PAD_IDX)

    return ids


# ═══════════════════════════════════════════════════════════
# Preparación de datos
# ═══════════════════════════════════════════════════════════
def load_data():
    with open(TRAIN_IN, encoding="utf-8") as f:
        dataset = json.load(f)
    with open(VOCAB_IN, encoding="utf-8") as f:
        vocab = json.load(f)
    with open(LABELS_IN, encoding="utf-8") as f:
        labels = json.load(f)

    # Invertir labels: categoria → índice
    label_to_idx = {cat: int(idx) for idx, cat in labels.items()}

    examples = dataset["examples"]

    X = np.array(
        [text_to_sequence(ex["text"], vocab) for ex in examples],
        dtype=np.int32,
    )
    y = np.array(
        [label_to_idx[ex["label"]] for ex in examples],
        dtype=np.int32,
    )

    return X, y, vocab, labels


def train_val_test_split(X, y):
    """Split determinista con shuffle previo."""
    n = len(X)
    indices = np.arange(n)
    np.random.shuffle(indices)

    n_test = int(n * TEST_SPLIT)
    n_val = int(n * VALIDATION_SPLIT)

    test_idx = indices[:n_test]
    val_idx = indices[n_test : n_test + n_val]
    train_idx = indices[n_test + n_val :]

    return (
        (X[train_idx], y[train_idx]),
        (X[val_idx], y[val_idx]),
        (X[test_idx], y[test_idx]),
    )


# ═══════════════════════════════════════════════════════════
# Construcción del modelo
# ═══════════════════════════════════════════════════════════
def build_model(vocab_size: int, num_classes: int) -> tf.keras.Model:
    """
    Modelo: Embedding + GlobalAveragePooling1D + Dense + Softmax.

    Razón de esta arquitectura:
    - Embedding aprende representaciones densas de tokens (ej: "uber" y "taxi"
      quedan cerca en el espacio vectorial).
    - GAP colapsa la secuencia a un vector fijo → permite input de longitud
      variable (ya paddeado a 8).
    - Dense(32) + ReLU aprende combinaciones no-lineales.
    - Dropout(0.3) previene overfitting con dataset sintético.
    - Softmax produce distribución de probabilidad sobre 20 categorías.

    Ventajas vs alternativas:
    - LSTM/GRU: 10x más lentos en inferencia, innecesarios para textos de <8
      tokens.
    - BERT: 100x más pesado, inviable para offline-first.
    """
    model = models.Sequential(
        [
            layers.Input(shape=(MAX_SEQ_LENGTH,), dtype=tf.int32, name="input_ids"),
            layers.Embedding(
                input_dim=vocab_size,
                output_dim=EMBEDDING_DIM,
                mask_zero=False,  # False para compatibilidad TFLite
                name="embedding",
            ),
            layers.GlobalAveragePooling1D(name="gap"),
            layers.Dense(DENSE_UNITS, activation="relu", name="dense_1"),
            layers.Dropout(DROPOUT_RATE, name="dropout"),
            layers.Dense(num_classes, activation="softmax", name="output"),
        ],
        name="beti_categorizer",
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=[
            "accuracy",
            tf.keras.metrics.SparseTopKCategoricalAccuracy(
                k=3, name="top3_acc"
            ),
        ],
    )

    return model


# ═══════════════════════════════════════════════════════════
# Conversión a TFLite
# ═══════════════════════════════════════════════════════════
def convert_to_tflite(keras_model: tf.keras.Model) -> bytes:
    """
    Convierte el modelo Keras a TFLite con cuantización dinámica.

    Cuantización dinámica: pesos float32 → int8 post-training.
    - Reduce tamaño ~4x (de ~800KB a ~200KB)
    - Inferencia más rápida en CPUs ARM (S25, iPhone)
    - Pérdida de accuracy típica: <1%
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)

    # Cuantización dinámica (la más segura para modelos con Embedding)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # Permitir ops TF select si hace falta (raro con esta arquitectura,
    # pero por seguridad). No agrega peso significativo al APK.
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
    ]

    tflite_bytes = converter.convert()
    return tflite_bytes


# ═══════════════════════════════════════════════════════════
# Evaluación post-TFLite (crítico: Keras y TFLite pueden diferir)
# ═══════════════════════════════════════════════════════════
def evaluate_tflite(tflite_path: Path, X_test: np.ndarray, y_test: np.ndarray):
    """Evalúa el modelo TFLite real (no el Keras) sobre el test set."""
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    correct = 0
    top3_correct = 0

    for i in range(len(X_test)):
        x = X_test[i : i + 1].astype(np.int32)
        interpreter.set_tensor(input_details["index"], x)
        interpreter.invoke()
        logits = interpreter.get_tensor(output_details["index"])[0]

        pred = int(np.argmax(logits))
        top3 = np.argsort(logits)[-3:][::-1]

        if pred == y_test[i]:
            correct += 1
        if y_test[i] in top3:
            top3_correct += 1

    return {
        "tflite_accuracy": correct / len(X_test),
        "tflite_top3_accuracy": top3_correct / len(X_test),
        "test_size": len(X_test),
    }


# ═══════════════════════════════════════════════════════════
# Matriz de confusión (para defensa académica)
# ═══════════════════════════════════════════════════════════
def confusion_summary(
    keras_model: tf.keras.Model,
    X_test: np.ndarray,
    y_test: np.ndarray,
    labels: dict,
) -> dict:
    """Top-3 confusiones más frecuentes (para el paper IEEE)."""
    preds = np.argmax(keras_model.predict(X_test, verbose=0), axis=1)

    confusion = {}
    for true_idx, pred_idx in zip(y_test, preds):
        if true_idx == pred_idx:
            continue
        true_cat = labels[str(true_idx)]
        pred_cat = labels[str(pred_idx)]
        key = f"{true_cat} → {pred_cat}"
        confusion[key] = confusion.get(key, 0) + 1

    top_confusions = sorted(
        confusion.items(), key=lambda x: -x[1]
    )[:10]

    return {k: v for k, v in top_confusions}


# ═══════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════
def main():
    print("═" * 60)
    print("Beti ML — Entrenamiento del Clasificador")
    print("═" * 60)

    # ─ Carga ──
    print("\n📂 Cargando dataset...")
    X, y, vocab, labels = load_data()
    print(f"   Total: {len(X)} ejemplos")
    print(f"   Vocab: {len(vocab)} tokens")
    print(f"   Clases: {len(labels)}")

    # ─ Split ──
    (X_train, y_train), (X_val, y_val), (X_test, y_test) = train_val_test_split(
        X, y
    )
    print(f"\n📊 Split:")
    print(f"   Train:      {len(X_train)} ({len(X_train) / len(X):.1%})")
    print(f"   Validation: {len(X_val)} ({len(X_val) / len(X):.1%})")
    print(f"   Test:       {len(X_test)} ({len(X_test) / len(X):.1%})")

    # ─ Modelo ──
    print("\n🧠 Construyendo modelo...")
    model = build_model(vocab_size=len(vocab), num_classes=len(labels))
    model.summary()

    # ─ Callbacks ──
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=EARLY_STOP_PATIENCE,
            restore_best_weights=True,
            verbose=1,
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(H5_CHECKPOINT),
            monitor="val_accuracy",
            save_best_only=True,
            verbose=0,
        ),
    ]

    # ─ Entrenamiento ──
    print("\n🏋️  Entrenando...")
    history = model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=2,
    )

    # ─ Evaluación Keras ──
    print("\n📈 Evaluación en test set (Keras)...")
    keras_eval = model.evaluate(X_test, y_test, verbose=0, return_dict=True)
    print(f"   Accuracy:      {keras_eval['accuracy']:.4f}")
    print(f"   Top-3 acc:     {keras_eval['top3_acc']:.4f}")
    print(f"   Loss:          {keras_eval['loss']:.4f}")

    # ─ Conversión TFLite ──
    print("\n🔄 Convirtiendo a TFLite (cuantización dinámica)...")
    tflite_bytes = convert_to_tflite(model)
    with open(MODEL_OUT, "wb") as f:
        f.write(tflite_bytes)
    size_kb = len(tflite_bytes) / 1024
    print(f"   Tamaño final: {size_kb:.1f} KB")

    # ─ Evaluación TFLite (para validar que no hubo drift) ──
    print("\n🔍 Validando modelo TFLite (no Keras)...")
    tflite_eval = evaluate_tflite(MODEL_OUT, X_test, y_test)
    print(f"   TFLite accuracy:     {tflite_eval['tflite_accuracy']:.4f}")
    print(f"   TFLite top-3 acc:    {tflite_eval['tflite_top3_accuracy']:.4f}")

    drift = abs(keras_eval["accuracy"] - tflite_eval["tflite_accuracy"])
    print(f"   Drift Keras→TFLite:  {drift:.4f} "
          f"({'✅ OK' if drift < 0.02 else '⚠️  REVISAR'})")

    # ─ Matriz de confusión ──
    print("\n🔀 Top confusiones (para paper IEEE):")
    confusion = confusion_summary(model, X_test, y_test, labels)
    for pair, count in list(confusion.items())[:5]:
        print(f"   {pair}: {count}")

    # ─ Reporte académico ──
    report = {
        "architecture": {
            "type": "Embedding + GAP + Dense",
            "embedding_dim": EMBEDDING_DIM,
            "dense_units": DENSE_UNITS,
            "dropout_rate": DROPOUT_RATE,
            "max_seq_length": MAX_SEQ_LENGTH,
            "total_params": int(model.count_params()),
        },
        "training": {
            "optimizer": "Adam",
            "learning_rate": LEARNING_RATE,
            "batch_size": BATCH_SIZE,
            "max_epochs": EPOCHS,
            "actual_epochs": len(history.history["loss"]),
            "early_stop_patience": EARLY_STOP_PATIENCE,
            "seed": SEED,
        },
        "dataset": {
            "total_examples": int(len(X)),
            "train_size": int(len(X_train)),
            "val_size": int(len(X_val)),
            "test_size": int(len(X_test)),
            "vocab_size": len(vocab),
            "num_classes": len(labels),
        },
        "metrics": {
            "keras_test_accuracy": float(keras_eval["accuracy"]),
            "keras_test_top3_accuracy": float(keras_eval["top3_acc"]),
            "keras_test_loss": float(keras_eval["loss"]),
            "tflite_test_accuracy": tflite_eval["tflite_accuracy"],
            "tflite_test_top3_accuracy": tflite_eval["tflite_top3_accuracy"],
            "keras_to_tflite_drift": float(drift),
            "final_val_accuracy": float(history.history["val_accuracy"][-1]),
        },
        "top_confusions": confusion,
        "artifact_size_kb": round(size_kb, 2),
    }

    with open(REPORT_OUT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"\n💾 Artefactos finales:")
    print(f"   {MODEL_OUT.relative_to(SCRIPT_DIR)}  ({size_kb:.1f} KB)")
    print(f"   {REPORT_OUT.relative_to(SCRIPT_DIR)}")
    print(f"\n✅ Listo. El .tflite está listo para copiarse a assets/ml/ del APK.")


if __name__ == "__main__":
    main()