---------- Script de maintenance SQL ----------
--
--                      !!
--                    !!  !!
--                  !!      !!
--                !!    OO    !!
--              !!      OO      !!
--            !!        OO        !!
--          !!          OO          !!
--        !!            OO            !!
--      !!                              !!    
--    !!                OO                !!
--  !!                                      !!
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   --

--- Une Sauvegarde de la base de donnée est indispensable avant éxécution ---
--- Un minimum de 35Go d'espace disque doit être disponible ---
--- Toutes les statistiques antérieures à la DEADLINE seront supprimés ---


--- Ce script supprimes des informations obsolètes --
--- et libère de l'espace disque dans le fichier de base de donnée --


-- vérification et modification du mode de récupération --
USE [master]
GO
ALTER DATABASE [DsPcDb] SET RECOVERY SIMPLE WITH NO_WAIT
GO
USE DsPcDb 
GO 

--Suppression des statistiques--
DECLARE @DeadlineAAAAMMJJ as datetime 
DECLARE @CurrentDate as datetime


-- DEADLINE à renseigner au format "AAAA MM JJ hh:mm:ss" -- ACTION REQUISE --
SET @DeadlineAAAAMMJJ = '2019-12-31 23:59:59'


SET @CurrentDate = CURRENT_TIMESTAMP
DELETE FROM ServiceUsage_T 
WHERE 
UsageEnd <= @DeadlineAAAAMMJJ or UsageEnd >= @CurrentDate
DELETE FROM CostSavings_T 
WHERE 
UsageEnd <= @DeadlineAAAAMMJJ or UsageEnd >= @CurrentDate
GO


-- Suppression des identités non utilisés --
DELETE 
FROM [DsPcDb].[dbo].[ConsumerIdentities_T]
  FROM [DsPcDb].[dbo].[ConsumerIdentities_T] as CI
   INNER JOIN [DsPcDb].[dbo].[ServiceConsumer_T] as C
 ON CI.ConsumerID = C.ID
 WHERE C.visibility = '1';
GO


-- Suppression des identités orphelines --
delete
  FROM [DsPcDb].[dbo].[ConsumerIdentities_T]
  where ConsumerID not in	(	
					Select ID
					from [DsPcDb].[dbo].[ServiceConsumer_T]
				)

GO


-- Suppression des évennements machine --
TRUNCATE TABLE Events_T
GO

-- Suppression des logs uniFLOW --

IF object_ID(N'BaSystemLog_T') IS NOT NULL
truncate table [dbo].[BaSystemLog_T]
GO

-- nettoyage des budgets --

DELETE FROM BudgetTransactions_T 
WHERE
Entity IN (SELECT ID FROM ServiceConsumer_T WHERE Visibility='1')


-- nettoyage des centres de cout --

DELETE FROM AllowedCostCenters_T
WHERE 
UserID IN (SELECT ID FROM ServiceConsumer_T WHERE Visibility='1' AND UserTypeEx='2') OR
CostCenterID IN (SELECT ID FROM ServiceConsumer_T WHERE Visibility='1' AND UserTypeEx='4096')


-- nettoyage des groupMember --

DELETE FROM GroupMembership_T
WHERE
UserID IN (SELECT ID FROM ServiceConsumer_T WHERE Visibility='1' AND UserTypeEx='2') OR
GroupID IN (SELECT ID FROM ServiceConsumer_T WHERE Visibility='1' AND UserTypeEx='4097')




-- Réorganisation des indexes --
EXEC sp_MSforeachtable 'ALTER INDEX ALL ON ? REBUILD WITH (FILLFACTOR = 95);'
EXEC sp_MSforeachtable 'UPDATE STATISTICS ? with FULLSCAN;'
DBCC CHECKDB WITH DATA_PURITY



-- Réduction du fichier journal & Base -- 
DBCC SHRINKFILE (N'DsPcDb' , 0, TRUNCATEONLY)
GO
DBCC SHRINKFILE (N'DsPcDb_log' , 0, TRUNCATEONLY)
