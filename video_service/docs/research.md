# PawCoach 调研：数据集与论文

> 用途：为「基于手机训练视频的宠物行为训练 Agent」MVP 提供数据与方法参考。
>
> **核实说明**（2026-11-12 联网核对）
> - 所有链接均已用 curl 测试可访问；论文 DOI / arXiv 编号已通过 Crossref 和 arXiv 核对标题与期刊一致；GitHub 仓库已通过 GitHub API 核对项目描述。
> - 「获取方式」一列说明是否需要申请。表中的规模数字（图片数、视频数等）来自论文摘要，具体以官方页面为准。

---

## 一、数据集

### A. 狗的姿态 / 关键点（量化「坐」「等待」保持时长等动作）

| 名称 | 简介 | 下载 | 获取方式 |
|---|---|---|---|
| **StanfordExtra** | 约 12,000 个狗实例的 2D 关键点和分割轮廓标注，基于 Stanford Dogs，是狗专用关键点数据集的首选。随 ECCV 2020 论文 WLDO 发布。 | https://github.com/benjiebob/StanfordExtra | 需填申请表获取标注 |
| **Stanford Dogs** | 120 个犬种、20,580 张图像，带类别与边界框。适合犬种识别、检测预训练。（斯坦福官网 http://vision.stanford.edu/aditya86/ImageNetDogs/ 核对时无法访问，可用下方镜像） | TFDS：https://www.tensorflow.org/datasets/catalog/stanford_dogs  Kaggle：https://www.kaggle.com/datasets/jessicali9530/stanford-dogs-dataset | 公开 |
| **DogPoseCV** ⭐ | 20,578 张狗图像（120 个犬种），人工标注为**站立 4,143 / 坐 3,038 / 卧 7,090 / 无法区分 6,307** 四类。基于 Stanford Dogs 重新标注，配套论文用它做了「识别到坐下就自动发零食」的实时设备。**和 MVP 的「坐下 / 等待保持」场景直接对应**，可用来训练逐帧姿态分类器。局限见下方评估。 | https://huggingface.co/datasets/stockeh/dog-pose-cv  代码：https://github.com/stockeh/canine-embedded-ml | 公开、免申请（标注 Apache-2.0；图片版权见下方说明） |
| **AP-10K** | 野外动物姿态估计基准：54 种哺乳动物、约 1 万张图、17 个关键点，含犬科。可作四足姿态通用预训练。 | https://github.com/AlexTheBad/AP-10K | 公开 |
| **APT-36K** | 视频级动物姿态估计与跟踪基准，约 2,400 段视频、36,000 帧、30 种动物。适合在视频中跨帧跟踪狗、计算动作持续时间。 | https://github.com/pandorgan/APT-36K | 公开 |
| **Animal Pose Dataset** | 5 类动物（狗、猫、牛、马、羊）的关键点标注，规模较小，可做补充。 | https://sites.google.com/view/animal-pose/ | 公开 |
| **DeepLabCut SuperAnimal-Quadruped** | 不是原始数据集，而是在大量四足动物图像上训练好的预训练关键点模型，零样本即可对狗视频推理，**MVP 最快起点**。 | 代码：https://github.com/DeepLabCut/DeepLabCut  模型：https://huggingface.co/mwmathis/DeepLabCutModelZoo-SuperAnimal-Quadruped | 开源 |
| **DogFLW** | 狗面部关键点数据集，用于面部关键点检测与表情分析（论文：Martvel et al., *Scientific Reports* 2025）。可用于识别应激、挫败等面部信号。 | Kaggle：https://www.kaggle.com/datasets/georgemartvel/dogflw  论文：https://doi.org/10.1038/s41598-025-07040-3 | 公开（Kaggle 登录下载） |
| **BARC / BITE** | 从单张图像重建狗的 3D 形状与姿态（CVPR 2022 / 2023），含犬种先验。可用于更精细的姿势判断（如坐姿是否到位）。 | BARC：https://github.com/runa91/barc_release  BITE：https://github.com/runa91/bite_release | 开源 |

#### DogPoseCV 可用性评估（2026-11-12）

**结论：可用，建议作为「坐 / 站 / 卧」姿态分类器的起步训练数据，但不能单独依赖。**

| 维度 | 评估 |
|---|---|
| 与需求的匹配度 | ✅ 高。标签正好是判断「坐下」「等待保持」需要的类别；把逐帧分类结果连起来，就能算出姿态保持了多少秒、中途断了几次。 |
| 基线效果 | ✅ 配套论文（Stock & Cavey, 2021）在测试集上准确率最高 92%，在 Jetson Nano 上能跑到 39 帧/秒，说明轻量模型就能在端侧运行。 |
| 获取难度 | ✅ 在 Hugging Face 上直接下载，不需申请，只有两个压缩包（图片 + 标签）。 |
| 数据形式 | ⚠️ 只有单张图片，没有视频，也没有时序标注和关键点。「保持时长」要靠逐帧分类结果平滑后再推算。 |
| 场景差异 | ⚠️ 图片来自网络图库（多是摆拍、宠物照），和手机拍摄的训练视频在视角、运动模糊、人狗同框、室内光线上差别较大，需要用自采视频帧微调。 |
| 类别质量 | ⚠️ 约 30% 是「无法区分」（多为面部特写），可用样本约 1.4 万张；「卧」的数量是「坐」的两倍多，需要过采样或加权。 |
| 版权与商用 | ⚠️ **标注是 Apache-2.0，但图片来自 Stanford Dogs / ImageNet，原图版权不属于数据集作者，ImageNet 的使用条款限于非商业研究。** 适合做原型和评估，正式商用的模型建议换成自采并经训犬师复核的数据。配套代码仓库没有声明许可证。 |
| 维护状态 | 最后更新于 2024-03，下载量较小（约 100 次），属于个人学术项目。 |

**建议用法**：先用 SuperAnimal 关键点（或直接用图像）在 DogPoseCV 上训练「坐 / 站 / 卧」分类器作为基线 → 再用几百段自采训练视频的抽帧微调 → 对逐帧结果做时序平滑，输出「坐下后保持了多少秒」。

### B. 动物行为 / 动作视频

| 名称 | 简介 | 下载 | 获取方式 |
|---|---|---|---|
| **Animal Kingdom** | CVPR 2022，约 50 小时标注视频、850 个物种，支持视频定位、细粒度动作识别、姿态估计三类任务，含狗的行为片段。 | https://github.com/sutdcv/Animal-Kingdom | 需申请 |
| **MammalNet** | CVPR 2023，约 18,000 段视频、539 小时、173 种哺乳动物、12 类高层行为。适合行为分类预训练。 | https://mammal-net.github.io/ | 公开 |
| **DECADE**（Who Let The Dogs Out?） | CVPR 2018，在狗身上安装摄像头和 IMU，记录狗的第一视角视频与关节运动，用于建模狗的行为与动作规划。 | https://github.com/ehsanik/dogTorch | 公开 |
| **Animal-Bench** | NeurIPS 2024，面向视频多模态大模型的动物视频理解评测基准。可用来评估你选用的 VLM 对动物动作的判断能力。 | https://github.com/PRIS-CV/Animal-Bench  论文：https://doi.org/10.52202/079017-2501 | 开源 |
| **MammAlps** | CVPR 2025，瑞士阿尔卑斯野生哺乳动物的多视角视频行为监测数据集。偏野生场景，可参考其行为层级标注方式。 | https://github.com/eceo-epfl/MammAlps  论文：https://doi.org/10.1109/cvpr52734.2025.01293 | 开源 |

### C. 传感器 / 情绪相关（真值参考与安全兜底）

| 名称 | 简介 | 下载 | 获取方式 |
|---|---|---|---|
| **Movement Sensor Dataset for Dog Behavior Classification**（Vehkaoja et al., 坦佩雷 / 赫尔辛基大学） | 45 只中大型犬在项圈和胸背带上佩戴 3D 加速度计 + 陀螺仪（100 Hz），完成坐、站、卧、走、小跑、玩耍、嗅闻找零食 7 种行为，每种约 3 分钟；由两路摄像机按 1 秒粒度标注并与传感器同步，附处理与分类代码。可借鉴其行为定义与标注规范。 | 数据：https://data.mendeley.com/datasets/vxhx934tbn/4  数据说明论文（*Data in Brief* 2022）：https://doi.org/10.1016/j.dib.2022.107822  分类论文（Kumpulainen et al., *AABS* 2021）：https://doi.org/10.1016/j.applanim.2021.105393 | 公开（CC BY 4.0） |
| **拉布拉多情绪视频**（Boneh-Shitrit et al., *Scientific Reports* 2022） | 29 只拉布拉多在受控实验中被诱导出「期待奖励（积极）」与「挫败（消极）」两种状态的视频，用 DogFACS 编码并做自动识别。原始实验见 Bremhorst et al., 2019。可用于识别训练中的挫败信号。 | 论文：https://www.nature.com/articles/s41598-022-27079-w  原始实验：https://www.nature.com/articles/s41598-019-55714-6 | 论文未公开数据下载地址，需向作者（Bremhorst / Zamansky）申请 |

### D. 人侧：口令、手势、奖励动作

| 名称 | 简介 | 下载 | 获取方式 |
|---|---|---|---|
| **COCO-WholeBody** | 在 COCO 上扩展人脸、手、脚共 133 个全身关键点，可识别训练者手势、递零食动作。 | https://github.com/jin-s13/COCO-WholeBody | 公开 |
| **MediaPipe Pose / Hands** | Google 端侧人体与手部关键点模型，可在手机上实时运行，适合检测「递零食」「拉牵绳」。 | https://ai.google.dev/edge/mediapipe/solutions/guide | 开源 |
| **Whisper** | OpenAI 开源语音识别，支持词级时间戳，可提取口令和标记词出现的时间。 | https://github.com/openai/whisper | 开源 |
| **FunASR / Paraformer** | 阿里达摩院开源中文语音识别工具包，中文效果好，支持时间戳与热词（可把「坐」「等」「好」设为热词）。 | https://github.com/modelscope/FunASR | 开源 |

> **空白点 = 机会**：目前没有找到公开的「人—犬训练互动」标注数据集（口令 → 动作 → 奖励的时序标注）。用户上传视频经训犬师复核后形成的标注数据，可以成为产品的核心壁垒。

---

## 二、论文

### 1. 训练科学（反馈规则依据）

| 论文 | 要点 | 链接 |
|---|---|---|
| Chiandetti et al., 2016, *Applied Animal Behaviour Science*, "Can clicker training facilitate conditioning in dogs?" | 对比响片与口头标记的训练效果，涉及标记与奖励的时机。 | https://doi.org/10.1016/j.applanim.2016.08.006 |
| Feng et al., 2018, *Applied Animal Behaviour Science*, "Is clicker training (Clicker + food) better than food-only training for novice companion dogs and their owners?" | 针对新手主人和家犬的对照实验，结果对「新手宠主是否需要响片」有直接参考价值。 | https://doi.org/10.1016/j.applanim.2018.04.015 |
| Demant et al., 2011, *Applied Animal Behaviour Science*, "The effect of frequency and duration of training sessions on acquisition and long-term memory in dogs" | 训练频率与单次时长对学习和长期记忆的影响，可直接用于生成练习计划的频率与时长规则。 | https://doi.org/10.1016/j.applanim.2011.05.010 |
| Vieira de Castro et al., 2020, *PLOS ONE*, "Does training method matter? Evidence for the negative impact of aversive-based methods on companion dog welfare" | 厌恶式训练会增加狗的应激行为和皮质醇水平，支持只推荐正向强化。 | https://doi.org/10.1371/journal.pone.0225023 |
| Ziv, 2017, *Journal of Veterinary Behavior*, "The effects of using aversive training methods in dogs—A review" | 综述厌恶式训练方法对狗的负面影响。 | https://doi.org/10.1016/j.jveb.2017.02.004 |
| China, Mills & Cooper, 2020, *Frontiers in Veterinary Science*, "Efficacy of Dog Training With and Without Remote Electronic Collars vs. a Focus on Positive Reinforcement" | 电击项圈与正向强化的对比实验，正向强化效果不差且福利更好。 | https://doi.org/10.3389/fvets.2020.00508 |
| Shih et al., 2021, *Frontiers in Veterinary Science*, "Dog Pulling on the Leash: Effects of Restraint by a Neck Collar vs. a Chest Harness" | **牵绳拉扯**：比较项圈与胸背带下的拉扯力度，可用于牵绳场景的装备建议。 | https://doi.org/10.3389/fvets.2021.735680 |
| Shih et al., 2020, *Animals*, "Who Is Pulling the Leash? Effects of Human Gender and Dog Sex on Human–Dog Dyads When Walking On-Leash" | **牵绳拉扯**：分析人和狗双方因素对牵绳拉扯的影响。 | https://doi.org/10.3390/ani10101894 |
| Waller et al., 2013, *PLoS ONE*, "Paedomorphic Facial Expressions Give Dogs a Selective Advantage" | 使用 DogFACS（狗的面部动作编码系统）的代表性研究，可用于识别恐惧、应激面部信号并触发转介。 | 论文：https://doi.org/10.1371/journal.pone.0082686  DogFACS 官网：https://www.animalfacs.com/ |
| AVSAB 立场声明 | 美国兽医动物行为学会关于人道训练、惩罚使用等的立场文件，可作为产品训练原则和转介规则的依据。 | https://avsab.org/resources/position-statements/ |

### 2. 计算机视觉与多模态方法

| 论文 | 要点 | 链接 |
|---|---|---|
| Stock & Cavey, 2021, arXiv, "Who's a Good Boy? Reinforcing Canine Behavior in Real-Time using Machine Learning" | **与本项目高度相关**：识别狗的「坐 / 站 / 卧」并实时触发零食投放器来奖励正确动作，测试准确率最高 92%，在 Jetson Nano 上 39 帧/秒。发布了 DogPoseCV 数据集，是「自动判断动作并在正确时机奖励」的直接先例。 | https://arxiv.org/abs/2101.02380 |
| Mathis et al., 2018, *Nature Neuroscience*, "DeepLabCut: markerless pose estimation of user-defined body parts with deep learning" | 少量标注即可训练动物无标记姿态估计，领域奠基工作。 | https://doi.org/10.1038/s41593-018-0209-y |
| Lauer et al., 2022, *Nature Methods*, "Multi-animal pose estimation, identification and tracking with DeepLabCut" | 多个体同时跟踪与姿态估计（狗与人同框时有用）。 | https://doi.org/10.1038/s41592-022-01443-0 |
| Ye et al., 2024, *Nature Communications*, "SuperAnimal pretrained pose estimation models for behavioral analysis" | 跨物种预训练姿态模型，零样本泛化，是 MVP 姿态提取的首选方案。 | https://doi.org/10.1038/s41467-024-48792-2 |
| Biggs et al., ECCV 2020, "Who Left the Dogs Out? 3D Animal Reconstruction with Expectation Maximization in the Loop" | 从单张图片重建狗的 3D 姿态，发布 StanfordExtra。 | https://arxiv.org/abs/2007.11110 |
| Ehsani et al., CVPR 2018, "Who Let The Dogs Out? Modeling Dog Behavior From Visual Data" | 从狗的第一视角视觉数据建模狗的行为（DECADE 数据集）。 | https://arxiv.org/abs/1803.10827 |
| Ng et al., CVPR 2022, "Animal Kingdom: A Large and Diverse Dataset for Animal Behavior Understanding" | 动物行为理解的大规模多任务基准。 | https://arxiv.org/abs/2204.08129 |
| Yu et al., NeurIPS 2021, "AP-10K: A Benchmark for Animal Pose Estimation in the Wild" | 野外动物姿态估计基准。 | https://arxiv.org/abs/2108.12617 |
| Yang et al., NeurIPS 2022, "APT-36K: A Large-scale Benchmark for Animal Pose Estimation and Tracking" | 视频动物姿态估计与跟踪基准。 | https://arxiv.org/abs/2206.05683 |
| Jing et al., NeurIPS 2024, "Animal-Bench: Benchmarking Multimodal Video Models for Animal-centric Video Understanding" | 评测视频大模型对动物行为的理解能力，可作为选型依据。 | https://doi.org/10.52202/079017-2501 |
| Martvel et al., 2025, *Scientific Reports*, "Investigating the capabilities of large vision language models in dog emotion recognition" | **与本项目高度相关**：直接测试大型视觉语言模型识别狗情绪的能力，可帮助判断「直接用大模型看视频」可靠到什么程度。 | https://doi.org/10.1038/s41598-025-25199-7 |
| Boneh-Shitrit et al., 2022, *Scientific Reports*, "Explainable automated recognition of emotional states from canine facial expressions" | 用 DogFACS 和深度学习两种方法自动识别狗的积极 / 挫败状态。 | https://doi.org/10.1038/s41598-022-27079-w |
| Anderson & Perona, 2014, *Neuron*, "Toward a Science of Computational Ethology" | 计算行为学综述，讨论如何把行为量化为可测量指标。 | https://doi.org/10.1016/j.neuron.2014.09.005 |
| Pereira et al., 2020, *Nature Neuroscience*, "Quantifying behavior to understand the brain" | 用机器学习量化动物行为的方法综述。 | https://doi.org/10.1038/s41593-020-00734-z |
| ActionFormer（Zhang et al., ECCV 2022） | 时序动作定位：从长视频中切出动作的起止时间，可用于切分「口令 → 动作 → 奖励」片段。 | https://github.com/happyharrycn/actionformer_release |

---

## 三、MVP 技术路线建议

1. **先聚焦一个场景：「等待 / 坐下保持」**。指标最容易量化：保持了几秒、动作中断几次、奖励是否在 1 秒内给出。
2. **处理流程**：
   SuperAnimal 提取狗的关键点 → 用 DogPoseCV 训练的小模型判断姿态（坐 / 站 / 卧），再做时序平滑 → FunASR 找到口令时间戳 → MediaPipe 识别递零食动作，得到奖励时间点 → 生成每天的结构化训练记录 → 由大模型（如 Claude）基于历史指标生成反馈和下一次练习计划。
3. **先算客观指标，再让大模型解释**：不要让大模型直接凭画面主观判断，可以降低误判风险（参考 Martvel et al. 2025 对视觉语言模型能力边界的评估）。
4. **安全兜底**：检测到攻击、恐惧信号（参考 DogFACS 和情绪识别研究）或训练者使用厌恶式方法时，提示转介给合格的行为专业人员。
