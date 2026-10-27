# Tandy-1000-LLM

**Exploring autoregressive language modeling on an original Tandy 1000 using assembly language.**

Tandy-1000-LLM is an experimental project investigating how far language modeling can be pushed on vintage PC hardware. Its primary target is an actual Tandy 1000 computer, with software designed around the processor, memory, storage, and operating environment available on the machine.

The project explores three central ideas:

- Implementing the application in assembly language for direct control over hardware resources.
- Investigating compact autoregressive language models that can operate within severe memory and performance constraints.
- Researching whether Model-Agnostic Meta-Learning (MAML) or related adaptation techniques can improve the usefulness of a model under those constraints.

The goal is not to put a modern, resource-intensive LLM on a vintage computer unchanged. It is to investigate what a language model specifically designed for vintage hardware can accomplish.

> **Project status:** Experimental research and development. Features, model capabilities, hardware compatibility, and performance must be verified against the actual implementation. This README describes the project goals and intended direction; it does not imply that all proposed components are already implemented.

## Table of Contents

- [Project Goals](#project-goals)
- [Target Hardware](#target-hardware)
- [Design Principles](#design-principles)
- [Language and Implementation Requirements](#language-and-implementation-requirements)
- [Proposed Architecture](#proposed-architecture)
- [Autoregressive Language Modeling](#autoregressive-language-modeling)
- [Meta-Learning and MAML](#meta-learning-and-maml)
- [Data Acquisition and Training](#data-acquisition-and-training)
- [Memory and Performance Engineering](#memory-and-performance-engineering)
- [Development Roadmap](#development-roadmap)
- [Testing and Validation](#testing-and-validation)
- [Limitations and Research Questions](#limitations-and-research-questions)
- [Contributing](#contributing)
- [License](#license)

## Project Goals

### Primary goals

1. **Target real hardware.** Design for execution on a physical Tandy 1000 rather than relying exclusively on a modern computer or emulator.
2. **Use assembly language.** Keep application code in assembly, with the instruction set and executable format selected for the target machine.
3. **Investigate autoregressive language modeling.** Explore compact representations, next-token prediction, and text generation appropriate for constrained hardware.
4. **Explore meta-learning.** Investigate MAML and related approaches to few-shot adaptation, with explicit evaluation of their practical costs and benefits.
5. **Minimize resource requirements.** Optimize memory use, model size, storage access, arithmetic, and execution speed.
6. **Measure actual results.** Document what runs on the target, how much memory it consumes, how quickly it generates text, and what capabilities it demonstrates.
7. **Preserve reproducibility.** Document model formats, datasets, training configurations, and evaluation procedures sufficiently for others to reproduce experiments.

### Long-term ambition

The long-term ambition is to investigate a complete language-model development pipeline, from acquiring text data and constructing training examples to training or adapting a model and running inference on vintage hardware.

The project will approach this ambition incrementally. Each stage must be validated before the next stage becomes a dependency.

## Target Hardware

### Baseline target

The baseline is the original Tandy 1000, an IBM PC-compatible computer built around the Intel 8088 processor.

Representative original-model specifications include:

| Component | Baseline specification |
|---|---|
| Processor | Intel 8088 |
| Processor clock | Approximately 4.77 MHz |
| Standard memory | 128 KB RAM |
| Potential system memory | Up to 640 KB, depending on installed expansion hardware |
| Storage | Original configuration included a 5.25-inch floppy drive |
| Operating environment | DOS-compatible software environment |
| Floating-point hardware | Not assumed to be present |

Actual available memory, storage, DOS version, expansion hardware, and other configuration details must be measured or verified on the target machine.

These specifications are a baseline, not a claim that every Tandy 1000-family machine has identical hardware.

### Hardware-first development

The software must not assume the availability of:

- A GPU or dedicated neural-network accelerator.
- Modern SIMD instruction sets.
- Large amounts of conventional memory.
- Virtual memory or a modern operating-system memory manager.
- A hard drive or high-capacity storage device.
- Modern networking hardware or an internet connection.
- Hardware floating-point instructions.

The initial implementation should target the original 8088 instruction set and the actual execution environment. Compatibility with later Tandy 1000 variants can be investigated separately.

### Memory is a first-class design constraint

A model that is theoretically small enough to store may still be impractical to execute.

The application must account for memory consumed by:

- Executable code and static data.
- Model weights.
- Tokenizer or vocabulary data.
- Input context and generated output.
- Intermediate activations and arithmetic buffers.
- Stack usage and DOS memory requirements.
- File buffers and other runtime state.

Model capacity must therefore be evaluated against the memory available to the application, not simply the computer's total installed RAM.

## Design Principles

### 1. Design for the target, not the modern equivalent

The architecture must reflect the actual capabilities and limitations of the Tandy 1000.

Modern model architectures can provide research inspiration, but they must not be assumed to be suitable without analysis and measurement.

### 2. Assembly-first implementation

Assembly is a core requirement, not a final optimization pass.

The implementation should favor explicit memory layouts, predictable resource use, carefully bounded buffers, and direct control over arithmetic and execution.

### 3. Correctness before optimization

Every component must be testable independently. Low-level optimization should follow correctness tests rather than replace them.

### 4. Small working systems before ambitious systems

The first meaningful milestone is a working, memory-bounded program that can process text and produce a verified result on the target hardware.

Subsequent milestones can introduce tokenization, model inference, training experiments, and adaptation.

### 5. Evidence over assumptions

No performance target, model capability, or research benefit should be treated as established until supported by repeatable measurements.

## Language and Implementation Requirements

### Assembly language

Application code is intended to be implemented in assembly appropriate to the target processor and execution environment.

For the original Tandy 1000, this means designing for the Intel 8088 and its 16-bit programming environment, including its 8-bit external data bus and segmented memory addressing.

The selected assembler, object format, executable format, and calling conventions must be documented once the build system is established.

### Execution environment

The initial target is a DOS-compatible environment appropriate for the baseline machine.

The executable format and memory model must be chosen to fit the actual requirements. A small `.COM` program may be appropriate for an early prototype, while a larger application may require an `.EXE` format or a different memory organization.

These choices should be made based on verified constraints rather than assumed in advance.

### No hidden modern runtime

The target application must not require a modern language runtime, GPU library, or external service to perform its core local execution.

Development tools and independent reference implementations may be used to test the assembly implementation, provided they are not silently required by the target executable.

If any preprocessing, model conversion, or offline training utility is introduced, its role must be documented separately from the assembly application.

## Proposed Architecture

The architecture will be developed in small, independently testable components.

```text
                DATA ACQUISITION
                       |
             Source filtering and
             dataset preparation
                       |
                       v
              TRAINING EXPERIMENTS
                       |
          Autoregressive objective
                       |
            Optional MAML research
                       |
                       v
             Compact model artifact
                       |
                Model validation
                       |
                       v
+-------------------------------------------+
|             TANDY 1000 TARGET             |
|                                           |
|  DOS-compatible assembly application      |
|                  |                        |
|          Input and tokenizer              |
|                  |                        |
|          Model and text context           |
|                  |                        |
|          Autoregressive inference          |
|                  |                        |
|          Text generation and output       |
+-------------------------------------------+
```

This is a conceptual architecture, not a statement that the entire pipeline already exists.

The eventual design may change substantially after the first executable and model-size experiments.

### Target-side components

The initial implementation is expected to investigate:

- Program initialization and DOS interaction.
- Memory allocation and bounded buffers.
- Text input and output.
- Token or symbol encoding.
- Model-weight loading, if the chosen format requires it.
- Model inference and next-token selection.
- Text generation within explicit resource limits.

Each component must be evaluated against the memory and execution constraints of the target.

### Training and data preparation

Training, data preparation, and inference are distinct workloads.

The project will investigate where each workload can realistically execute. Full internet-scale data acquisition and training must not be assumed to fit on the Tandy 1000 simply because the final application targets that machine.

If offline preparation or training is used, the resulting artifacts must have a documented format and a verified path to target-side execution.

The precise division between on-device and offline work remains a design decision to be established through experiments.

## Autoregressive Language Modeling

Autoregressive language modeling predicts the next symbol or token from the preceding context.

For a sequence \(x_1, x_2, \ldots, x_T\), a standard autoregressive objective is:

\[
\mathcal{L}(\theta) =
-\sum_{t=1}^{T}
\log P_\theta(x_t \mid x_{<t})
\]

Here, \(\theta\) represents the model parameters and \(x_{<t}\) represents the sequence preceding position \(t\).

The objective is conceptually straightforward. Implementing a useful model under vintage hardware constraints is not.

### Research questions

- Which tokenization strategy provides a useful balance between vocabulary size, sequence length, and memory consumption?
- Is character-level, byte-level, subword, or another compact representation most appropriate?
- What model architecture can execute within the available memory?
- Can fixed-point or integer arithmetic reduce the computational burden without unacceptable loss of quality?
- How much context can the application maintain?
- What generation speed and output quality can be demonstrated on actual hardware?

The project will begin with the simplest architecture that permits meaningful, measurable experiments.

A conventional transformer must not be treated as the default solution if its memory and computational requirements make it impractical for the target.

### Model evaluation

Model evaluation should distinguish between:

- Whether the implementation is numerically and functionally correct.
- Whether the model learns from training data.
- Whether generated output has measurable language-modeling quality.
- Whether the model is usable at the speed and memory footprint of the target.

A program that generates text is not, by that fact alone, evidence of a capable language model.

## Meta-Learning and MAML

Model-Agnostic Meta-Learning is a research direction for learning parameter initializations that can adapt to new tasks with relatively few gradient updates.

In simplified form, an inner-loop update for task \(i\) can be written as:

\[
\theta'_i =
\theta - \alpha
\nabla_\theta \mathcal{L}_{\mathcal{T}_i}(\theta)
\]

An outer-loop update then optimizes the initial parameters based on the adapted models:

\[
\theta \leftarrow \theta -
\beta \nabla_\theta
\sum_i \mathcal{L}_{\mathcal{T}_i}(\theta'_i)
\]

Here, \(\alpha\) and \(\beta\) are learning rates, and \(\mathcal{T}_i\) denotes a training task.

This describes the general concept, not a completed implementation.

### Why investigate MAML?

The research question is whether meta-learning can produce a compact model that adapts more effectively to new text patterns or tasks than a comparable model trained conventionally.

Potential evaluation areas include:

- Few-shot adaptation.
- Learning from small task-specific datasets.
- Adaptation quality under strict memory limits.
- Training cost relative to the improvement achieved.
- Whether the resulting parameters remain suitable for target-side inference.

### MAML is not assumed to be beneficial

MAML does not guarantee better language modeling, greater intelligence, or lower inference costs.

Full MAML training requires gradient computation and an outer optimization procedure that may be impractical on an original Tandy 1000. The research must determine whether the intended training procedure can run on the target, requires offline execution, or should be replaced by a simpler adaptation strategy.

The project should compare meta-learning against a conventional autoregressive baseline using the same evaluation tasks and clearly documented resource budgets.

## Data Acquisition and Training

### Broad data coverage

The long-term research ambition includes investigating how to acquire and prepare text from a broad range of internet-accessible sources.

This does not imply that the original Tandy 1000 can download, store, and train on the entire internet. Its processing speed, memory, storage, and networking constraints make that an entirely separate problem from target-side inference.

Data acquisition and preparation must be treated as a distinct subsystem with explicit hardware and storage requirements.

### Dataset quality and provenance

Any dataset used for training should have documented provenance and processing steps.

Where applicable, data preparation should include:

- Source identification and access-policy checks.
- Format normalization.
- Duplicate and near-duplicate removal.
- Quality filtering.
- Handling of malformed and hostile input.
- Removal or exclusion of sensitive information where appropriate.
- Dataset versioning and reproducibility.
- Documentation of licensing and other applicable restrictions.

Data availability does not automatically confer permission to use that data for model training.

### Training strategy

Training experiments should begin with a small, documented dataset and a measurable objective.

The project should establish a working baseline before increasing corpus size or adding meta-learning.

The following questions must be resolved experimentally:

1. Can the selected model architecture be trained at all within the intended compute environment?
2. Where can training realistically occur?
3. What model format can be loaded by the target executable?
4. How are weights represented, validated, and converted?
5. What quality is lost when model size or numeric precision is reduced?
6. Does MAML provide a measurable improvement over the baseline?

Training and inference must remain separate in the design until their respective resource requirements are understood.

## Memory and Performance Engineering

The application must measure its resource usage rather than rely on theoretical model size alone.

### Memory budgeting

For every model configuration, record:

- Model-weight storage.
- Runtime working memory.
- Maximum input-context size.
- Maximum generated-output buffer.
- Stack and code requirements.
- Temporary arithmetic storage.
- Remaining available memory.

The application must reject unsupported model configurations safely rather than corrupt memory or overwrite unrelated data.

### Arithmetic

The project should investigate numeric representations that are practical on an 8088-class processor.

Possible research areas include:

- Integer arithmetic.
- Fixed-point representations.
- Reduced-precision weights.
- Lookup tables for selected operations.
- Carefully bounded intermediate values.
- Precomputed values where they reduce execution cost.

Each optimization must be evaluated for both correctness and performance. Numeric approximations can change model output, so their effects must be measured.

### Performance benchmarks

Where supported by the target, benchmark:

- Executable size.
- Model artifact size.
- Available and consumed memory.
- Initialization and model-loading time.
- Time to generate the first output.
- Tokens or symbols generated per second.
- Maximum supported context.
- Output quality on a fixed evaluation set.

Measurements should identify the exact hardware, clock speed, memory configuration, software version, and model used.

Emulator results may assist development, but results from actual hardware should be identified separately.

## Development Roadmap

The following roadmap describes proposed milestones. Items should only be marked complete after implementation and verification.

### Phase 1 — Establish the target

- [ ] Confirm the exact Tandy 1000 model and installed hardware.
- [ ] Document the DOS version and available memory.
- [ ] Select an appropriate 8088-compatible assembler and executable format.
- [ ] Establish a reproducible build process.
- [ ] Produce a minimal assembly executable that runs on the target.
- [ ] Verify execution on physical hardware or a clearly identified emulator.

### Phase 2 — Build the runtime foundation

- [ ] Implement bounded memory and buffer management.
- [ ] Implement text input and output.
- [ ] Establish error handling and safe termination.
- [ ] Measure baseline executable and runtime memory usage.
- [ ] Create repeatable functional tests.

### Phase 3 — Establish a language-model baseline

- [ ] Evaluate tokenization and vocabulary alternatives.
- [ ] Define a compact model representation.
- [ ] Implement a minimal inference path.
- [ ] Load or embed a small, validated model artifact.
- [ ] Generate text on the target.
- [ ] Measure model size, memory consumption, and generation speed.

### Phase 4 — Investigate training

- [ ] Define a reproducible training dataset.
- [ ] Establish a conventional autoregressive training baseline.
- [ ] Define how training artifacts are transferred to the target.
- [ ] Validate model conversion and loading.
- [ ] Compare training and inference resource requirements.

### Phase 5 — Investigate meta-learning

- [ ] Define the task distribution and adaptation objective.
- [ ] Implement or evaluate an appropriate MAML procedure.
- [ ] Compare against the conventional training baseline.
- [ ] Measure adaptation quality and computational cost.
- [ ] Determine which parts, if any, can execute on the target.

### Phase 6 — Optimize and document

- [ ] Profile execution on the target.
- [ ] Optimize the most expensive operations.
- [ ] Measure the effects of reduced-precision representations.
- [ ] Document limitations and reproducible benchmarks.
- [ ] Publish verified hardware compatibility and model results.

## Testing and Validation

The project should use independent reference calculations and automated tests during development, even though the target application itself is intended to be written in assembly.

Testing should cover:

- Arithmetic correctness.
- Buffer boundaries and memory safety.
- Tokenization and decoding.
- Model loading and artifact validation.
- Deterministic inference tests where applicable.
- Malformed input and truncated files.
- Out-of-memory and unsupported-model conditions.
- Repeatability across builds.
- Differences between emulator and physical-hardware results.

Any reference implementation used for comparison should be clearly identified and kept separate from the target application.

Testing must not silently depend on a modern runtime being available on the Tandy.

## Limitations and Research Questions

This project operates under constraints that differ radically from modern language-model development.

### Training scale

Training a modern, general-purpose language model from scratch on an original Tandy 1000 is not a realistic baseline expectation. The available compute, memory, and storage are exceptionally limited.

The project must determine what training tasks are feasible rather than assume that contemporary model sizes and methods can be reproduced on the target.

### Internet access and data volume

Collecting a broad internet corpus is not equivalent to processing it on the Tandy. Data acquisition, storage, preparation, and training have separate resource requirements and may require a distinct offline workflow.

### Model capability

A small model may learn limited patterns and generate text without providing the broad knowledge or reasoning ability of a modern LLM. Capabilities must be evaluated against explicit tests rather than inferred from the use of autoregressive modeling or MAML.

### Meta-learning feasibility

MAML may impose substantial computational and memory overhead. Whether its benefits justify that cost is an open research question.

### Compatibility

The initial baseline is the original Tandy 1000. Support for other Tandy 1000-family models, alternate DOS versions, additional memory configurations, and expanded storage must be tested separately.

## Contributing

Contributions are welcome, particularly those that improve correctness, hardware compatibility, memory efficiency, reproducibility, and the quality of the research.

Useful contributions include:

- 8088 assembly implementation and optimization.
- DOS compatibility testing.
- Memory-layout and executable-size analysis.
- Compact model representations.
- Tokenization and numeric-precision experiments.
- Autoregressive training and evaluation research.
- MAML feasibility studies.
- Documentation and reproducible benchmarks.
- Physical-hardware testing.

Please include the target hardware and software environment when reporting results. Performance claims should include reproducible measurements whenever possible.

Before introducing a dependency or architectural change, consider whether it is compatible with the project's target hardware and assembly-language requirements.

## License

The project's license must be specified in the repository's `LICENSE` file.

Until a license is selected and committed, do not assume that the source code or associated model and dataset artifacts are available for unrestricted redistribution or reuse. Model weights and datasets may have licensing terms separate from those of the application.

## Project Repository

- Repository: https://github.com/saviornt/Tandy-1000-LLM
- Issues: https://github.com/saviornt/Tandy-1000-LLM/issues
- Pull requests: https://github.com/saviornt/Tandy-1000-LLM/pulls

---

**Tandy-1000-LLM is an investigation into the limits of language modeling on vintage hardware.** Its success will be measured by what can be implemented, verified, and demonstrated on the target machine—not by assumptions that modern AI architectures will work unchanged on a computer designed decades before today's LLMs.
