ALTER TABLE `content_detection_record`
  ADD COLUMN `risk_sub_category` VARCHAR(128) NULL DEFAULT NULL COMMENT '风险二级类别' AFTER `risk_category`,
  ADD COLUMN `risk_score` INT NULL DEFAULT NULL COMMENT '风险置信度' AFTER `risk_sub_category`,
  ADD COLUMN `hit_details_json` JSON NULL COMMENT '命中字段及片段定位；不保存完整提交原文' AFTER `risk_score`;
