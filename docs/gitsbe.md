# Gitsbe {-}

[Gitsbe] is an acronym for *Genetic Interactions To Specific Boolean Equations*.
This module defines boolean models compliant with observed behavior (e.g. steady state or perturbation data) using an automated, model parameterization genetic algorithm.



The code of the package is available in Bitbucket.

This documentation is for the software version `1.2.11`

## Description {-#gitsbe-description}

The model interactions (taken from a network file, see [inputs] section) are first assembled to logical boolean equations, based on a **default equation** relating a node with its regulators:

:::{.blue-box .note}
Target *= (A or B or C) and not (D or E or F)
:::

where the *activating* regulators `A`, `B` and `C` and the *inhibitory* regulators `D`, `E` and `F` of a target node are combined with logical `or` operators between them and connected with the `and not` *link operator*.
Thus, the state of the target node can be calculated using boolean algebra (0 means *inhibited*, 1 *active*).

----

Gitsbe uses a **genetic algorithm** to generate and parameterize boolean models that fit to the [training data] observations.
First, an initial generation of models is formulated from the input model, where a large number of **mutations** to the parameterization is [introduced](#gen-algo-params): for example, randomly selected equations are mutated to use the `or not` link operator instead of the `and not`.
Then for each model, a *fitness* score is computed as the weighted average over all fitness values for each observation that is specified in the [training data] file.
During this step, the calculation of the [models attractors](#attractor-tool) takes place.
The models that achieve the highest fitness scores will be **selected** for the next generation (see [respective configuration options](#gen-algo-params)) and will be used during the **crossover phase** to exchange logical equations between them (also including themselves - enabling *asexual reproduction*!).
This is how the models of the new generation are determined.
After that, the **mutation phase** is repeated as described above, followed by the calculation of the attractors and the subsequent **selection phase**.

After a non-negative total fitness score is obtained for the worst of the best models in the current generation, the number of mutations introduced per generation is reduced by a user-specified factor (see [options](#gen-algo-params)).
The whole **evolution** process is halted either when a user-specified fitness threshold is reached or when the (also user-defined) maximum number of generations had been spanned.
The highest-fitness models of the last generation are stored in a `models` directory (see [Outputs]).
Different simulations of the **evolution** process can be run from the initial model (can be done in *parallel* utilizing all available cores), using a different seed per simulation and thus creating different parameterized output models in each case.

## Installation and Usage {-#gitsbe-install}

### Install {-}

Prerequisites: `maven 3.6.0` and `Java 8`.

Installation commands:
```
git clone https://bitbucket.org/asmundf/gitsbe.git
mvn clean install
```

:::{.note}
Note that [Gitsbe] calculates attractors for the boolean models it generates using either the [BNReduction tool](https://github.com/alanavc/BNReduction) [@Veliz-Cuba2014] or the [BioLQM](https://github.com/colomoto/bioLQM) Java library [@Naldi2018]. BioLQM is included by default in the code.
The BNReduction tool has to be manually installed following the [respective documentation](https://bitbucket.org/asmundf/druglogics_dep/src/master/).
:::

### Example {-}

The recommended way to run Gitsbe is to use it's `Launcher`.
From the root directory of the repo run:
```
cd example_run_ags
java -cp ../target/gitsbe-1.2.11-jar-with-dependencies.jar eu.druglogics.gitsbe.Launcher --project=test --network=toy_ags_network.sif --trainingdata=toy_ags_training_data.tab --config=toy_ags_config.tab --modeloutputs=toy_ags_modeloutputs.tab
```

or run the `mvn` profile directly (same input as the command above through the `pom.xml`):
```
mvn compile -P runExampleAGS
```

### Inputs {-}

Running the Gitsbe `Launcher` with no parameters, generates a **usage message** with the available options.
The **required** parameters are:

- `--network`: a single-interactions network file (in Cytoscape's `.sif` format, *tab-delimited*, with binary signed and directed interactions)
- `--trainingdata`: [training data file](#training-data)
- `--modeloutputs`: [model outputs file](#modeloutputs)
- `--config`: [configuration file](#gitsbe-config)

The **non-required** parameters are:

- `--project`: the project name which is used as the name of the directory where the [outputs] will be stored.
- `--drugs`: [drugpanel file](#drugpanel): this is required only when the training data observations include either [single](#single-drug) or [double](#double-drug) drug perturbation conditions.

### Outputs {-}

The expected generated outputs of the `Launcher` are:

- A `models` directory with files in `.gitsbe` format (or [other formats](#export) as well if properly specified), which represent the boolean models that best fitted to the configuration and training data that the simulation of the genetic algorithm was based on.
- A **summary file** that includes the models' fitness evolution throughout the genetic algorithm's generations.
- The **initial boolean model** exported in many [standard formats](#export) (e.g. `.gitsbe`, `.sif`, `.ginml`).

## Training Data {-}

The training data file includes specific *condition-response* pairs (**observations**) which are used to calculate the fitness of the boolean models during the **evolution** process of the [genetic algorithm](#gitsbe-description).
For each observation, a different *fitness* score is calculated.
Every fitness score is between $0$ (no fitness at all) and $1$ (perfect fitness).
The format of each observation is:

::: {.blue-box .fitcontent}
**Condition**  
\<data\>  
**Response**  
\<data\>  
**Weight**:\<number\>
:::

The **weight** numbers (can be continuous values) are used after each individual observation *fitness* score has been calculated, to derive a **total weighted average fitness score** for the model which is *fitted* to the training data.

We now present the currently **supported observations**:

### Unperturbed Condition - Steady State Response {-}

Example:

::: {.blue-box .fitcontent}
**Condition**  
\-  
**Response**  
A:0 B:1 C:0 D:0.453  
**Weight**:1
:::

This is the most commonly used training option.
Note that the response values are *tab-separated* and that the numbers assinged to each of the entities, define an activity value in the $[0,1]$ interval (continuous values are allowed).
The entities have to be nodes from the [initial network](#inputs), otherwise they are ignored.
Thus, a boolean model with it's attractors calculated, gets a fitness score for this kind of observation that describes how **close it's attractors are to the specified steady state response**.

For example, if a boolean model has only 1 trapspace attractor, on which the nodes {A,B,C,D} have values {0,1,-,-}, the fitness would be:
$$fitness=\frac{\sum matches}{\#responses}=\frac{1+1+(1-abs[0-0.5])+(1-abs[0.453-0.5])}{4}=\frac{3.453}{4} \simeq 0.86$$

If a model has multiple attractors, then first we find the average number of matches across all attractors and then divide by the number of responses.
For example, if the previous model had one more attractor for which the nodes perfectly matched the observed responses (so $4$ in total matches) we would have an average value of matches across the two attractors equal to $(4+3.453)/2=3.7265$ and a *fitness* thus equal to $3.7265/4\simeq0.93$ (which makes sense since the second attractor matched better the observed state and thus **boosted** the fitness).

### Unperturbed Condition - `globaloutput` Response {-}

Example:

::: {.blue-box .fitcontent}
**Condition**  
\-  
**Response**  
globaloutput:1  
**Weight**:1
:::

This training option pretty much translates to: **if I leave the system unperturbed, it continues proliferating** - a direct description of a cancer cell network system.
So, with this type of observation we can train models to match a **growing cell/proliferation profile**.

Note that the **Response** must always be in the `globaloutput:<number>` format and that the absolute observed `globaloutput` response can take any value in the $[0,1]$ interval (from a cell death state to a cell proliferation state so to speak).
We mostly define it as an $1$ in this kind of observation.

In order to find the *fitness* of a boolean model to this kind of observation, we first calculate it's attractors, compute it's *normalized predicted* `globaloutput` $gl_{pred}$ using Equation No. \@ref(eq:modeloutputsnorm) and then calculate:
$$fitness=1-abs(gl_{obs}-gl_{pred})$$

where $gl_{obs}$ is the value defined in the **Response** (usually $1$ in this case).

### Knockout/Overexpression Condition {-}

Example:

::: {.blue-box .fitcontent}
**Condition**  
A:0 B:1  
**Response**  
globaloutput:0  
**Weight**:0.1
:::

The above example translates to: *knockout* of A and *overexpression* of B entities (e.g. proteins/genes) combined, result in complete cell death (these observations are usually based on some experimental data).
So with this kind of observation, we **train our model's output behaviour to best fit an experimental tested knockout or overexpression of one or many biological entities**.

The **Response** must always be in the `globaloutput:<number>` format, with `<number>` a continuous value in the $[0,1]$ interval (ranging from cell death to a cell proliferation state).

The **Condition** must have *tab-separated* nodes with activity values (one or many).
The activity values must be either $0$ or $1$, otherwise they are ignored.
This is because we use logical modeling and substitute the equations of the boolean model as `A *= false` and `B *= true` respectively, before we calculate its attractors (both `A` and `B` must be in the [defined network model](#inputs)).
After the attractors of the modified model are calculated, we compute it's *normalized predicted* `globaloutput` $gl_{pred}$ using Equation No. \@ref(eq:modeloutputsnorm) and then calculate:
$$fitness=1-abs(gl_{obs}-gl_{pred})$$

where $gl_{obs}$ is the value defined in the **Response** (usually $0$ in this case).

### Single Drug Perturbation {-#single-drug}

Example:

::: {.blue-box .fitcontent}
**Condition**  
Drug(A)  
**Response**  
globaloutput:0  
**Weight**:0.1
:::

With this observation we define **how a single drug perturbation affects our model's output state** (based on experimental data).

The **Response** must always be in the `globaloutput:<number>` format, with `<number>` a continuous value in the $[0,1]$ interval (ranging from cell death to a cell proliferation state).

The **Condition** must be in the `Drug(<DrugName>)` format, where the `<DrugName>` is one of the drugs defined in the [drug panel](#drugpanel).
Thus we can find the drug's (defined) targets and perturb our model accordingly: if for example the `PI` drug *inhibits* entity `A` (the target) we change our model's respective equation to `A *= false`.
Same logic if the drug had *activating* targets - the respective equations change to `Target *= true` (note that this is scarcely used since most drugs inhibit their targets).

Once the model is modified and it's attractors calculated, we compute it's *normalized predicted* `globaloutput` $gl_{pred}$ using Equation No. \@ref(eq:modeloutputsnorm) and then calculate:
$$fitness=1-abs(gl_{obs}-gl_{pred})$$

where $gl_{obs}$ is the value defined in the **Response** (usually $0$ in this case).

### Double Drug Perturbation {-#double-drug}

Example:

::: {.blue-box .fitcontent}
**Condition**  
Drug(A+B) < min(Drug(A),Drug(B))  
**Response**  
globaloutput:-0.2  
**Weight**:1
:::

In this particular case, we can **train our model to best fit a synergistic observation between two drugs**.

To derive that two drugs are synergistic, the experimental data are analyzed with various mathematical and computational models which compare the *actual observed response* with the *predicted (by the model) non-interaction* response.
If the measured response is lower than the expected non-interaction one, a synergy is defined and the *excess* - the relative `globaloutput` ($gl_{rel}$) between the actual response and the predicted non-interaction response - is used an input in the **Response** (format: `globaloutput:<number>`).

A negative value for the relative globaloutput $gl_{rel}$/`<number>` defines a synergistic response while a positive value an antogonistic one (so we can also **train the model for antagonism** between the two drugs).
Given that the *observed* and *non-interaction* responses are in the $[0,1]$ interval (ranging from cell death to a cell proliferation state), their difference (the relative `globaloutput`) must belong in the $[-1,1]$ interval (ranging from a highly synergistic to a highly antagonistic relationship between the 2 drugs).

For the calculation of the model's *fitness* we can use either an *HSA* (Highest Single Agent) **Condition** (as in the example above) where the format would be `Drug(A+B) < min(Drug(A),Drug(B))` (`A` and `B` are drugs defined in the [drug panel](#drugpanel)) or a *Bliss* **Condition** [@BLISS1939], with the `Drug(A+B) < product(Drug(A),Drug(B))` format.
In each case, we compute the attractors of 3 models: one perturbed with drug `A` alone, one perturbed with drug `B` alone and one perturbed with (the targets of) both drugs.
Then, using the attractors of each model and Equation No. \@ref(eq:modeloutputsnorm), we compute each respective *normalized predicted* `globaloutput` as: $gl_A,gl_B,gl_{A+B}$.

Then:

- In the case of an *HSA* **Condition**, we compute the minimum globaloutput $gl_{min}=min(gl_A,gl_B)$ and then the *HSA* excess as: $excess=gl_{A+B}-gl_{min} \in [-1,1]$.
- In the case of a *Bliss* **Condition**, we compute the globaloutput product $gl_{product}=gl_A\times gl_B$ and then the *Bliss* excess as: $excess=gl_{A+B}-gl_{product} \in [-1,1]$

Next, in order to find how close that *excess* is to the one given in the training observation (the relative `globaloutput` $gl_{rel}$), we calculate their absolute difference and normalize it to get a value in the $[0,1]$ interval with which we can find the *fitness*:
$$fitness=1-\frac{abs(excess-gl_{rel})}{2}$$

## Modeloutputs {-}

The `modeloutputs` is an input file that is used by both [Gitsbe] and [Drabme].
In the file, **network nodes with their respective integer weights** are defined, like in the example below:

::: {#example-modeloutputs .green-box .fitcontent}
RPS6KA1 &emsp; 1  
MYC &emsp; 1  
TCF7 &emsp; 1  
CASP8 &emsp; -1  
CASP9 &emsp; -1  
FOXO3 &emsp; -1
:::

The nodes are *tab-separated* with the values and indicate the entities that directly influence the cell's global *signaling output* or *growth*: nodes that have a *negative* output value weight contribute to **cell death** through various means (e.g. `CASP8`) and nodes that have a *positive* value contribute to **cell proliferation** (e.g. `MYC`).
We allow only integer values for the node weights while their magnitude allows to distinct each node by how much do they influence cell death/proliferation: for example, a weight of $-2$ for the node `CASP8` would make it twice more important for cell death as a node who has a value of $-1$.

So, for each [training data observation](#training-data) where we need to calculate a (predicted) `globaloutput` value for a boolean model and for which we already have it's attractors (stable states or terminal trapspaces), we find the **values of the modeloutput nodes in each attractor** (can be either $1$, $0$ or a dash ($-$): *active*, *inactive* or the node's activity oscillates between the two) and calculate the following weighted average score across all attractors:

\begin{equation}
  gl_{pred} = \frac{\sum_{j=1}^{k}\sum_{i=1}^{n}ss_{ij} \times w_i}{k}
  (\#eq:modeloutputs)
\end{equation}

where $k$ is the number of attractors of the model, $n$ is the number of nodes defined in the `modeloutputs` file, $w_i$ their respective weights and $ss_{ij}$ is the state of node $i$ in the $j$-th attractor (can be one of $0$, $1$ or $0.5$ in case of a dash ^[And that's a good approximation when we are talking about boolean models. It could be the case though, that a particular node which (in the trapspace result) has an activity defined by a dash ($-$) oscillates between $1000$ states, out of which it's active in $900$ of them and inactive in the rest. So a more correct value in that case would be a $0.9$]).
We always normalize the `globaloutput` to the $[0,1]$ range by using the $max(gl)=\sum_{w_i>0}w_i$ and $min(gl)=\sum_{w_i<0}w_i$ values and calculating:

\begin{equation}
  gl_{norm} = \frac{gl_{pred}-min(gl)}{max(gl)-min(gl)}
  (\#eq:modeloutputsnorm)
\end{equation}

For example, for a boolean model that has $k=1$ attractor, Equation \@ref(eq:modeloutputs) becomes:

\begin{equation}
  gl_{pred} = \sum_{i=1}^{n} ss_i \times w_i
  (\#eq:modeloutputs1ss)
\end{equation}

So, if we have a boolean model whose modeloutput nodes are defined as in the [example above](#example-modeloutputs) (a subset of the total model nodes) and which has $1$ trapspace where `RPS6KA1`=$1$, `MYC`=`TCF7`=$-$ and `CASP8`=`CASP9`=`FOXO3`=$0$, then using Equation \@ref(eq:modeloutputs1ss):

$$gl_{pred}=1\times1+0.5\times1+0.5\times1+0\times-1+0\times-1+0\times-1=2$$

and since $min(gl)=-3$ and $max(gl)=+3$, the *normalized* globaloutput value is $gl_{norm}=\frac{2-(-3)}{3-(-3)}=0.833$.

## Configuration {-#gitsbe-config}

The configuration file includes options that are common between [Gitsbe] and [Drabme] (see [General] and [Attractor Tool] options), those that are Gitsbe-specific (see [Export] and [Genetic Algorithm](#gen-algo-params) options) and those that are [Drabme-specific](#drabme-config).

The format of each configuration option in the file must be: `<parameter>:  <value>` (*tab-separated*)

### General {-}

- `verbosity`. Allowed values: $0$-$3$ ($0$ = nothing, $3$ = everything).

  This option is used for logging purposes since both Gitsbe and Drabme create a `log` directory where various logging messages are written in files.

- `delete_tmp_files`. Logical (`true` or `false`).

  Gitsbe and Drabme create `<name>_tmp` directories (one each, `<name>` is either `gitsbe` or `drabme`) which are used to store the logical model files that are created throughout the simulations.
  If this option is `true`, a `FileDeleter` object is enabled that monitors the temporary directories and deletes the logical model files after they are used (e.g. when their attractors are calculated).
  After the simulations are finished, the `<name>_tmp` directories get deleted as well.

- `compress_log_and_tmp_files`. Logical (`true` or `false`).
  
  Use this option to archive the files inside the `log` directory as well as the `<name>_tmp` directories.
  The output format is `.tar.gz`.
  This option is usually used when the `verbosity` is $3$ and the number of simulations (`simulations` parameter) is high (e.g. $>100$).

- `use_parallel_sim`. Logical (`true` or `false`).
  
  States whether the simulations will run in parallel, utilizing thus all the machine's cores.

- `parallel_sim_num`. Allowed values: $>1$.
  
  The number of simulations to execute in parallel if the previous option (`use_parallel_sim`) is `true`.
  A good value for this option would be to have **as many parallel simulations as the machine's cores** but we advise to reduce it if too many parallel simulations are causing issues.

### Attractor Tool {-}

- `attractor_tool`: tool to use for the calculation of attractors.

  Allowed values: `bnet_reduction`, `bnet_reduction_reduced`, `biolqm_stable_states`, `biolqm_trapspaces`.

  The first two options use the [BNReduction tool](https://github.com/alanavc/BNReduction) [@Veliz-Cuba2014] and the next two the [BioLQM](https://github.com/colomoto/bioLQM) Java library [@Naldi2018].
  Follow the [respective documentation](https://bitbucket.org/asmundf/druglogics_dep/src/master/) to install and enable the two BNReduction-based versions (BioLQM is included by default).

  The `bnet_reduction` and `biolqm_stable_states` options calculate **all the fixpoints** of the boolean models.
  The `bnet_reduction_reduced` works only if the model has **one fixpoint attractor** (or none). 
Note though that there can be models that have one fixpoint and the *reduced* BNReduction version is not able to find it.
  It's advantage rests on the simple fact that **it's much faster for larger networks** and when self-contained network models are used, it gets most of the results correctly (self-contained models usually don't have many fixpoints).
  
  The `biolqm_trapspaces` option calculates the *terminal* trapspaces (see respective [BioLQM documentation](http://colomoto.org/biolqm/doc/tools-trapspace.html)).
  These kind of trapspaces are also called *minimal* [@Klarner2015].

### Export {-}

Options for **trimming** the [initial network file](#inputs):

- `remove_output_nodes`. Logical (`true` or `false`).

  Removes nodes *recursively* from the model that have no *outgoing* edges.
  
- `remove_input_nodes`. Logical (`true` or `false`).

  Removes nodes *recursively* from the model that have no *incoming* edges.

Options for **exporting** the [initial network file](#inputs) to different formats:

- `export_to_gitsbe`. Logical (`true` or `false`)

  An example of a simple network in `gitsbe` format:
  
  ::: {.blue-box .fitcontent}
  **modelname**: test_model  
  **fitness**: 0.82  
  **stablestate**: 110  
  **equation**: A \*= B or C  
  **equation**: B \*= A  
  **equation**: C \*= !A  
  **mapping**: A = x1  
  **mapping**: B = x2  
  **mapping**: C = x3  
  :::
  
  The `gitsbe` format includes the following information: 
    - Model's name
    - Model's fitness score (gained via fitting to the [training data])
    - Model's attractors, if they are calculated (`stablestate` or `trapspace` - one per line)
    - The boolean equations, in *BooleanNet* format [@Albert2008]
    - A mapping between node names and variables (mainly used with the [BNReduction tool](https://github.com/alanavc/BNReduction))

- `export_to_sif`. Logical (`true` or `false`)

  The Cytoscape’s single-interaction format. 
  Example of a topology with two *activating* interactions and an *inhibiting* one:
  
  ::: {.blue-box .fitcontent}
  B -> A  
  C -> A  
  A -> B  
  A -| C
  :::
  

- `export_to_ginml`. Logical (`true` or `false`)

  GINsim's XML-based [GINML format](http://www.colomoto.org/formats/ginml.html).
  This export is enabled via the BioLQM library [@Naldi2018].

- `export_to_sbml_qual`. Logical (`true` or `false`)

  [SBML-qual](http://www.colomoto.org/formats/sbml-qual.html) is an extension of the *Systems Biology Markup Language (SBML)* Level 3 standard, designed for the representation of multivalued qualitative models of biological networks.
  This export is enabled via the BioLQM library [@Naldi2018].

- `export_to_boolnet`. Logical (`true` or `false`)

  The R package's *BoolNet* format [@Mussel2010]. 
  This export is also enabled via the BioLQM library [@Naldi2018].
  Example:
  
  ::: {.blue-box .fitcontent}
  targets, factors   
  A, B|C  
  B, A  
  C, !A
  :::
  

We also provide export options for the **best models** generated via the genetic algorithm of Gitsbe for each simulation.
Note that these models are automatically saved in `gitsbe` format (by default) inside the `models` directory for [input](#drabme-input) to Drabme.
The export formats are the same as the three last ones described above:

- `best_models_export_to_ginml`. Logical (`true` or `false`)
- `best_models_export_to_sbml_qual`. Logical (`true` or `false`)
- `best_models_export_to_boolnet`. Logical (`true` or `false`)

### Genetic Algorithm {-#gen-algo-params}

The following options are used to initialize, configure and calibrate the [genetic algorithm of Gitsbe](#gitsbe-description):

- `simulations`. Allowed values: $\ge 1$.

  Number of simulations (evolutions) to run.
  Each simulation is based on a different seed so it's quaranteed to be different than the others and also reproducible.
  The seed determines the random choices that are taken throughout the evolution process of fitting the models to the [training data].

- `models_saved`. Allowed values: $\ge 1$.

  Number of models to save per simulation.
  These models are saved in a `models` directory that [Drabme can use](#drabme-input) and are the highest fitness models of the last generation.

- `fitness_threshold`$\in [0,1]$

  Fitness threshold for saving models per simulation: if a best model does not have a fitness score larger than the `fitness_threshold` value, it is not saved.

- `generations`. Allowed values: $\ge 1$.

  Number of generations per simulation.
  Note that the actual number of generations might be less if the `target_fitness` value is surpassed.

- `target_fitness`: $\in (0,1]$

  Target fitness threshold to stop evolution.
  If any of the best models in a generation achieves fitness higher than the `target_fitness` value, the corresponding simulation is stopped.

- `population`. Allowed values: $\ge 1$.

  Number of models per generation.

- `selection`. Allowed values: $\ge 1$.

  Number of models selected for the next generation (during **selection phase**).
  These are the models that had the best fitness scores among all the models of their generation.

- `crossovers`. Allowed values: $\ge 1$.

  At the end of each generation, the best models are selected (higher fitness) and they exchange equations between them to determine the models of the new generation (**crossover phase**).
  The number of crossovers defines how many *splitting points* we are going to have in the equations so as to split them between two *parent* best models that give birth to a *child* model.
  For example, if `crossovers = 1`, we randomly select one splitting point and all the equations up to that point (index programmatically) are copied from the first parent while the rest of the equations are copied from the other parent model.
  Thus the child model is a mix of equations between the two parent models and the higher the number of crossovers are, the more *complex* that mix becomes.
  If the number of crossovers is larger than the number of equations, then we take one equation alternatively from each parent and give it to the child model.

- `balance_mutations`
- `random_mutations`
- `shuffle_mutations`
- `topology_mutations`
  
  Allowed values: $\ge 0$.
  After the models of each generation are created, the **mutation phase** takes place, during which a number of possible mutations are introduced to the models.
  The 4 different kind of mutations that can be applied to randomly chosen equations of a logical model are:

  - **Balance**: `and not` <=> `or not`. Also called *link operator* mutations.
  - **Random**: `(A or B)` <=> `(A and B)`. A change of boolean operator which denotes a different relationship between the entities (e.g. family nodes vs complex nodes).
  - **Shuffle**: `(A or (B and C))` <=> `(B or (A and C))`. Also called *priority* mutations.
  - **Topology**: `(A or B)` <=> `(B)`. Involves the addition and/or removal of regulation edges.

These mutations can be applied at the *initial* stage and after it.
A simulation starts at the *initial* stage and comes out of it when **the worst of the best models in a generation has a non-zero fitness score** (usually this means that there is a model with an attractor).

The difference before and after the initial stage is how many of these mutations are going to be applied.
For that purpose, we can configure **multiplication factors** that are used to *boost* the above mutations during the initial phase (`bootstrap_*_factor` options) and *lessen* them after it is over (`*_factor` options). 
Note that all values are $\ge 0$.
  
- `bootstrap_mutations_factor`
- `bootstrap_shuffle_factor`
- `bootstrap_topology_mutations_factor`
- `mutations_factor`
- `shuffle_factor`
- `topology_mutations_factor`

  We usually use a large number of mutations in the initial stage (high `bootstrap_*_factor`, e.g. $1000$) to ensure that a **large variation in parameterization can be explored**.
  Then, a value of $1$ for the `*_factor` options will ensure that we just apply the number of mutations as they were specified in the `*_mutations` options.
  Note that the `bootstrap_mutations_factor` and `mutations_factor` are used to multiply both the *random* and *balance* mutation options.
