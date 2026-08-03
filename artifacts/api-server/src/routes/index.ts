import { Router, type IRouter } from "express";
import healthRouter from "./health";
import rRouter from "./r/index";

const router: IRouter = Router();

router.use(healthRouter);
router.use(rRouter);

export default router;
